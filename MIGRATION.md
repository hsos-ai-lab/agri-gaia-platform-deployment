# Migration Guide

Step-by-step upgrade instructions for operators running an existing Agri-Gaia platform deployment. Each section applies only when upgrading from a version that predates the listed change.

For a changelog of what changed and why, see [CHANGELOG.md](CHANGELOG.md).

---

## Upgrading to Triton 24.09 — NVIDIA driver `>=575` required

As of the 2026-06-01 platform upgrade, the Triton inference server image was bumped from `nvcr.io/nvidia/tritonserver:23.12-py3` to `24.09-py3`. The new image is built against **CUDA 12.6**, which requires **NVIDIA driver branch `575` or newer**. Hosts running an older driver will fail to start the `triton` container.

This section applies to **GPU hosts only** (i.e. where `nvidia-smi` is installed and the `triton` Docker Compose profile is enabled). CPU-only hosts can skip it.

### 1. Check the current driver version

```bash
nvidia-smi --query-gpu=driver_version --format=csv,noheader
```

If the reported version is `575.xx` or higher, no action is needed. If lower (e.g. `535.xx`, `550.xx`), continue below.

### 2. Stop the platform and any GPU workloads

```bash
cd /opt/agri-gaia/platform
docker compose down

# Also stop any JupyterHub / Nuclio user containers — they hold the driver open
docker ps --filter "name=jupyter-" -q | xargs -r docker stop
docker ps --filter "name=nuclio"   -q | xargs -r docker stop
```

### 3. Install the new driver (Ubuntu 22 / 24)

```bash
sudo apt-get update
sudo apt-get install -y nvidia-driver-575-server   # headless / server hosts
# or, on hosts with a desktop session:
# sudo apt-get install -y nvidia-driver-575
```

If `nvidia-driver-575-server` is not available from your default repositories, enable NVIDIA's CUDA apt repository first (see [CUDA Downloads](https://developer.nvidia.com/cuda-downloads)) and install `cuda-drivers-575` instead.

### 4. Reboot

```bash
sudo reboot
```

A reboot is required — the running kernel module cannot be swapped out while the GPU is in use.

### 5. Verify and redeploy

After the host comes back up:

```bash
nvidia-smi                       # confirm driver is 575.xx+ and the GPU is detected
docker info | grep -i runtime    # confirm the `nvidia` runtime is still registered

cd /opt/agri-gaia/deploy
./deploy.sh
```

If the `nvidia` Docker runtime is missing after the upgrade, re-register it:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Once `deploy.sh` finishes, confirm Triton came up healthy:

```bash
docker compose -f /opt/agri-gaia/platform/docker-compose.yml logs triton | tail -50
curl -sf http://localhost:8000/v2/health/ready && echo "Triton OK"
```

---

## Upgrading to Nuclio 1.16.4 — existing functions must be redeployed

As of the 2026-06-04 platform upgrade, Nuclio was bumped from `1.8.18` to `1.16.4`. The new version enforces **DNS-1123 naming** for functions: only lowercase letters, digits, and hyphens are accepted. Names with dots or underscores (common in model archives uploaded via the annotation workflow) are rejected.

`deploy.sh` handles the version upgrade automatically. Manual steps are only required if you have existing Nuclio functions deployed on the platform.

### 1. Remove existing functions

In the Nuclio dashboard (`https://nuclio.<AG_PROJECT_BASE_URL>`), delete all deployed functions before running `deploy.sh`. Alternatively, from the host:

```bash
docker ps --filter "name=nuclio-" -q | xargs -r docker rm -f
```

### 2. Repackage function archives with DNS-1123 compliant names

Simply renaming the zip file is not sufficient. The backend derives nuctl's `--path` from the zip filename (minus `.zip`), so the **top-level folder inside the zip and the `metadata.name` field in `function.yaml` must all match the new filename**. A mismatch causes nuctl to fail with `Failed to resolve function config path`.

For each archive whose name contains dots or underscores (e.g. `pth.facebookresearch.sam.vit_h.zip`):

```bash
# 1. Unzip
unzip pth.facebookresearch.sam.vit_h.zip

# 2. Rename the inner folder to the new DNS-1123 compliant name
mv pth.facebookresearch.sam.vit_h sam-vit-h

# 3. Update metadata.name inside function.yaml
sed -i 's/name: pth.facebookresearch.sam.vit_h/name: sam-vit-h/' sam-vit-h/function.yaml

# 4. Rezip with the matching filename
zip -r sam-vit-h.zip sam-vit-h
```

### 3. SAM archive: replace `main.py` and `model_handler.py`

SAM archives downloaded directly from the Facebook repository or from a CVAT release newer than 2.4.2 are **not compatible** with the platform's CVAT 2.4.2 installation. Their `main.py` returns a base64-encoded embedding blob intended for client-side ONNX decoding, but CVAT 2.4.2 expects full server-side inference returning `{"points": [...], "mask": [...]}`. The result is a silent failure — annotation clicks produce no output and the browser console shows `Cannot read properties of undefined (reading 'length')`.

Before rezipping, replace the two Python files with the server-side versions from the matching CVAT tag:

```bash
# Download the correct files from the cvat-ai/cvat v2.4.2 tag
curl -o sam-vit-h/main.py \
  https://raw.githubusercontent.com/cvat-ai/cvat/v2.4.2/serverless/pytorch/facebookresearch/sam/nuclio/main.py
curl -o sam-vit-h/model_handler.py \
  https://raw.githubusercontent.com/cvat-ai/cvat/v2.4.2/serverless/pytorch/facebookresearch/sam/nuclio/model_handler.py
```

The `function.yaml` does not need to change — the `version: 2` annotation is metadata only under CVAT 2.4.2 and does not affect the inference protocol.

### 4. Redeploy

Run `./deploy.sh` as normal. The backend image is rebuilt automatically, picking up the matching `nuctl` 1.16.4 binary. Re-upload and deploy your repackaged function archives via the platform UI afterwards.

---

## Upgrading to EDC `edc` — subdomain rename from `edc-provider`

As of the 2026-06-15 platform upgrade, the Eclipse Dataspace Connector service was renamed from `edc_provider` to `edc`. The public subdomains changed accordingly:

| Old subdomain | New subdomain |
|---------------|---------------|
| `edc-provider.<base>` | `edc.<base>` |
| `edc-provider-web.<base>` | `edc-web.<base>` |
| `edc-provider-ids.<base>` | `edc-ids.<base>` |

`deploy.sh` applies this automatically. However, any **external data space participants or connector configurations** that reference the old `edc-provider.*` endpoints must be updated to point to the new addresses. New TLS certificates for the renamed subdomains are issued automatically on the next deployment when using a Let's Encrypt or ACME SSL mode.
