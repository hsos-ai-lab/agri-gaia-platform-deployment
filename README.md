# Agri-Gaia Platform Deployment

## Overview

![Overview of the Deployment Process](docs/deployment-process.png)

## Prerequisites

> **Note**: All commands and scripts in this guide must be run as `root` on the target host.

### Install Deploy Keys

**Note**: This step is only required if you're not using the [public GitHub repositories](https://github.com/hsos-ai-lab) of the Agri-Gaia project.

From a remote machine with the GitLab and GitHub deploy keys already in use, copy the required SSH keys to the new platform host:

```bash
scp -i ~/.ssh/agri-gaia-keypair/id_ed25519 -r \
  root@remote:/root/.ssh/agri-gaia \
  root@host:/root/.ssh
```

You should see the following directories with public and private keys inside root's `/root/.ssh` directory:

```text
/root/.ssh/agri-gaia
├── backend
│   ├── id_ed25519
│   └── id_ed25519.pub
├── frontend
│   ├── id_ed25519
│   └── id_ed25519.pub
└── platform
    ├── id_ed25519
    └── id_ed25519.pub
```

### Clone this Repository

Clone the contents of this repository into `/opt/agri-gaia/deploy`:

```bash
AG_SOURCE_DIR=/opt/agri-gaia \
  ; mkdir -p "${AG_SOURCE_DIR}" \
  && cd "${AG_SOURCE_DIR}" \
  && git clone https://github.com/hsos-ai-lab/agri-gaia-platform-deployment.git deploy \
  && cd deploy
```

**Warning**: If you've forked this project into a private repository and want to [manage multiple instances](#managing-multiple-instances), you'll have to clone the private repository using SSH and a deploy key. This is necessary to avoid `git pull` to hang while fetching updates to this repository on a remote host due to password authentication.

## Create Deployment Configuration

Run the following command to create a deployment specific `.env` file by answering the prompts presented to you:

```bash
./setup-env.sh
```

Also take a look at the [example `.env`](scripts/.env.example) file.

> **Note**: The script exits immediately if `scripts/.env` already exists, so it is safe to re-run only after removing that file.

### `setup-env.sh` Input Reference

The script asks the following questions in order. All inputs are **required** unless marked *optional*.

| Prompt | Variable written to `.env` | Description |
|--------|---------------------------|-------------|
| Git base URL | `AG_GIT_BASE_URL` | Hostname of your Git server without a trailing slash, e.g. `github.com`. Used to construct clone URLs for all three repositories. |
| Platform repository | `AG_GIT_REPOSITORY_PLATFORM` | Repository name (not the full URL) of the Agri-Gaia platform, e.g. `agri-gaia-platform`. |
| Platform git branch | `AG_GIT_BRANCH_PLATFORM` | Branch or tag to check out when cloning the platform repo, e.g. `main`. |
| Backend repository | `AG_GIT_REPOSITORY_BACKEND` | Repository name of the backend service, e.g. `agri-gaia-backend`. |
| Backend git branch | `AG_GIT_BRANCH_BACKEND` | Branch or tag to use for the backend repository. |
| Frontend repository | `AG_GIT_REPOSITORY_FRONTEND` | Repository name of the frontend service, e.g. `agri-gaia-frontend`. |
| Frontend git branch | `AG_GIT_BRANCH_FRONTEND` | Branch or tag to use for the frontend repository. |
| Git organization | `AG_GIT_ORGANIZATION` | The organisation or user that owns all three repositories on the Git server, e.g. `hsos-ai-lab`. |
| Public repositories? | `AG_GIT_PUBLIC_REPOSITORIES` | Answer `Y` if the repositories are publicly accessible without credentials; `N` if they require SSH deploy keys (see [Install Deploy Keys](#install-deploy-keys)). |
| Project base URL | `AG_PROJECT_BASE_URL` | The root domain for all platform sub-domains, e.g. `agri-gaia.example.com`. **Must not exceed 50 characters** — this limit exists because Traefik registers wildcard sub-domains and Let's Encrypt enforces a 64-character CN limit. |
| SSL mode | `AG_SSL_MODE` | TLS certificate strategy (see table below). Defaults to `lets-encrypt-http` if left blank. |

#### SSL mode options

| Value | When to use | Additional prompts triggered |
|-------|-------------|------------------------------|
| `lets-encrypt-http` | Public server reachable on port 80; Let's Encrypt HTTP-01 challenge. | ACME email |
| `lets-encrypt-dns` | Server behind a firewall or using DuckDNS dynamic DNS; Let's Encrypt DNS-01 challenge. | ACME email, DuckDNS token |
| `http-acme-eab` | Private/enterprise CA with External Account Binding (e.g. HARICA). | ACME email, CA server URL, EAB key ID, EAB HMAC |
| `issued` | You already have a wildcard `.crt` / `.key` pair from a trusted CA; no automated renewal. | *(none)* |
| `self-signed` | Local or air-gapped development environments; browsers will show a warning. | Whether to create / overwrite existing self-signed certificates |

#### Remaining prompts (after SSL mode)

| Prompt | Variable | Description |
|--------|----------|-------------|
| Production deployment? | `AG_DEPLOY_MODE` | Answer `Y` for production. This forces secure credentials and disables public user registration. Answer `N` for a development instance. |
| Secure credentials? *(development only)* | `AG_SECURE_CREDENTIALS` | Shown only when `N` was answered above. Answer `Y` to still generate random passwords; `N` to use short default credentials (convenient for local testing). |
| NVIDIA NGC API key | `AG_NVIDIA_NGC_API_KEY` | *Optional.* API key from [ngc.nvidia.com](https://ngc.nvidia.com/setup/api-key) used to pull private NGC container images (e.g. Triton). Leave blank if not needed. |
| GPU IDs | `AG_GPUS` | *Optional.* Comma-separated GPU indices as listed by `nvidia-smi -L` (e.g. `0` or `0,1`). Leave blank on CPU-only hosts. |
| GitHub personal access token | `AG_GITHUB_TOKEN` | *Optional.* Fine-grained GitHub PAT with read access, used to pull container images from GitHub Container Registry. Leave blank if not needed. |
| Flags for `docker compose down` | `AG_COMPOSE_DOWN_FLAGS` | Flags passed to `docker compose down` at the start of each deployment (e.g. `-v` to also delete all Docker volumes). Leave blank to keep volumes between redeployments. |
| EDC keystore password | `AG_EDC_KEYSTORE_PASSWORD` | Password for the `keystore.jks` file that you place in `/opt/agri-gaia/secrets` (see [Place Secrets](#place-secrets)). Must match the password the keystore was created with. |

> **Auto-generated values**: After your inputs are collected, the script automatically generates random 20-character alphanumeric passwords for Traefik, Keycloak, MinIO, Fuseki, PostgreSQL, PostGIS, CVAT, Grafana, and Portainer. These are written to `scripts/.env` and do not require any action from you.

### Setup the Host

Run the following command to install Docker and various other utility programs needed for deployment:

```bash
./setup-host.sh
```

This script will also install the NVIDIA Container Toolkit if a compatible GPU is detected.

## Place Secrets

Before running `deploy.sh`, create the following directory structure under `/opt/agri-gaia/secrets`. The deployment process copies its contents into the cloned platform repository, where Docker Compose picks them up via volume mounts.

The only required secret for a standard deployment is the EDC keystore, which must be placed in the `edc/` subdirectory:

```bash
mkdir -p /opt/agri-gaia/secrets/edc
```

**Optional**: If you plan to use already issued wildcard TLS certificates (`AG_SSL_MODE=issued`) and don't want to create your own private fork of the `agri-gaia-platform` repository, create the subdirectory `/opt/agri-gaia/secrets/certs/issued` and place your `.crt` und `.key` files into that directory. The filenames can be arbitrary, as the deployment process will read the `AG_PROJECT_BASE_URL` from your custom deployment `.env` file.

### EDC Keystore

The Eclipse Dataspace Connector (EDC) requires a Java keystore (`keystore.jks`) to establish secure data-plane connections. Copy it from the machine where it was generated into the `edc/` subdirectory of your secrets folder:

```bash
scp /path/to/keystore.jks root@host:/opt/agri-gaia/secrets/edc/keystore.jks
```

If you are migrating from an existing deployment, the keystore is typically already at `/opt/agri-gaia/secrets/edc/keystore.jks` on the source host:

```bash
scp root@old-host:/opt/agri-gaia/secrets/edc/keystore.jks \
    root@new-host:/opt/agri-gaia/secrets/edc/keystore.jks
```

At this point in time the `AG_SOURCE_DIR` should contain the following directories, with `secrets/certs/*` being optional (see above):

```text
/opt/agri-gaia/
├── deploy
└── secrets
    ├── edc
    │   └── keystore.jks
    └── certs
        └── issued
```

## Run `deploy.sh`

Deploy the Agri-Gaia platform with the configuration from your `.env` file using the following command:

```bash
# Usage: ./deploy.sh [<AG_GIT_BRANCH_PLATFORM>] [<AG_VOLUMES_TO_REMOVE>]
./deploy.sh
```

This command will execute `./scripts/deploy.sh` with two optional parameters acting as overrides for `AG_GIT_BRANCH_PLATFORM` and `AG_VOLUMES_TO_REMOVE` inside a `screen` session named `<id>.ag-deploy`. You can attach your terminal to that screen session by running the following command:

```bash
screen -r <id>

# or if only one screen session is running
screen -r
```

To list all active screen sessions use `screen -ls`. To detach from a screen session hit `Ctrl+A` followed by `D`.

## Migration

For step-by-step upgrade instructions, see [MIGRATION.md](MIGRATION.md).

## Managing Multiple Instances

If multiple instances of the Agri-Gaia platform are running on different hosts, redeployment of the platform can be automated:

1. For each instance, add the following JSON object to the root object in `instances.json`:

    ```json
    {
      "<name>": {
        "host": "<AG_PROJECT_BASE_URL of instance>",
        "ip": "<host ip>",
        "port": <SSH port of host>,
        "user": "<SSH user on host>"
      }
    }
    ```

2. Make sure your local user can access each host via the _same_ keypair using `ssh`. You might have installed that keypair in `~/.ssh/agri-gaia-keypair` or a different subdirectory.

3. For private deployment repo only: Make sure the remote host can pull from the Platform Deployment's private git repository via SSH. To achieve this, register the SSH public key of the platform repository as a deploy key of the Platform Deployment's repository. After that, add the following to the _remote host's_ `/root/.ssh/config` file:

    ```bash
    set -a
    source scripts/.env
    cat >> /root/.ssh/config <<EOL
    Host agri-gaia-platform-deployment.${AG_GIT_BASE_URL}
          HostName ${AG_GIT_BASE_URL}
          User git
          IdentityFile /root/.ssh/agri-gaia/platform/id_ed25519
          IdentitiesOnly yes
    EOL
    set +a
    ```

4. Run the re-deploy script with your local (non-privileged) user:

    ```bash
    ./redeploy-instances.sh \
      -b <git_branch> \
      [-f <instances_file>] \
      [-t <targets>] \
      [-v <volumes_to_remove>] \
      [-i <identity_file>]
    ```

    * If you would like to re-deploy only a subset of instances from `instances.json`, use the `-t` option and specify a **comma separated** list of instance names without spaces.
    * If you would like to remove Docker Volumes on the remote before re-deploying, use the `-v` option and specify a **comma separated** list of volume names without spaces as shown by `docker volume ls`.

    The following code snipped illustrates the usage of `redeploy-instances.sh` by re-deploying the platform on `dev` and `testing` instances from the `development` branch while removing the `agri_gaia_model-training` and `agri_gaia_cvat-logs` volumes:

    ```bash
    ./redeploy-instances.sh \
      -b development \
      -f instances.json \
      -t dev,testing \
      -v agri_gaia_model-training,agri_gaia_cvat-logs \
      -i ~/.ssh/agri-gaia/platform/id_ed25519
    ```

    Please note that the identity file specified by `-i` is used to connect from you local machine to the host system you want to deploy the platform to.
