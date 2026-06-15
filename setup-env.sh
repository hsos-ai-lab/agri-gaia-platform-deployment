#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024 Osnabrück University of Applied Sciences
# SPDX-FileContributor: Andreas Schliebitz
# SPDX-FileContributor: Henri Graf
# SPDX-FileContributor: Jonas Tüpker
# SPDX-FileContributor: Lukas Hesse
# SPDX-FileContributor: Maik Fruhner
# SPDX-FileContributor: Prof. Dr.-Ing. Heiko Tapken
# SPDX-FileContributor: Tobias Wamhof
#
# SPDX-License-Identifier: MIT

env_filepath="./scripts/.env"

[[ -f "${env_filepath}" ]] \
	&& { echo "Found existing .env '${env_filepath}' for deployment. Exiting..."; exit 1; }

echo "Please enter the base url of your git server, e.g. github.com"
read -rp "Git base url: " -e git_base_url

echo "Please enter the platform repository name, e.g. agri-gaia-platform"
read -rp "Platform repository: " -e git_repository_platform

echo "Please enter the git branch of the platform repository you want to use, e.g. main"
read -rp "Platform git branch: " -e git_branch_platform

echo "Please enter the backend repository name, e.g. agri-gaia-backend"
read -rp "Backend repository: " -e git_repository_backend

echo "Please enter the git branch of the platform backend repository you want to use, e.g. main"
read -rp "Backend git branch: " -e git_branch_backend

echo "Please enter the frontend repository name, e.g. agri-gaia-frontend"
read -rp "Frontend repository: " -e git_repository_frontend

echo "Please enter the git branch of the platform frontend repository you want to use, e.g. main"
read -rp "Frontend git branch: " -e git_branch_frontend

echo "Please enter the name of the git organization the repositories are part of, e.g. hsos-ai-lab"
read -rp "Git organization name: " -e git_organization

read -rp "Are you deploying from public git repositories? (Y/N): " -e git_public_repositories

git_public_repositories=$([[ $git_public_repositories =~ ^[nN]([oO])?$ ]] && echo false || echo true)
# This has to change if any new subdomain is added which is longer than 13 characters. 
echo "Please enter the project base url, e.g. agri-gaia.example.com. Note: It must not be longer than 50 characters."
read -rp "Project base url: " -e project_base_url

echo ""
echo "Which ssl mode do you want to use?"
echo "Options are: lets-encrypt-http (default), lets-encrypt-dns, http-acme-eab, issued, self-signed"
read -rp "SSL mode (enter for default): " -e ssl_mode

[[ -z "${ssl_mode}" ]] && ssl_mode="lets-encrypt-http"

if [[ "${ssl_mode}" == "lets-encrypt"* || "${ssl_mode}" == "http-acme-eab" ]]; then
	echo ""
	echo "Please enter the email address that shall be used for acme (can be any)"
	read -rp "ACME email: " -e acme_email
fi

if [[ "${ssl_mode}" == "lets-encrypt-http" ]] || [[ "${ssl_mode}" == "issued" ]]; then
	:
elif [[ "${ssl_mode}" == "lets-encrypt-dns" ]]; then
	echo ""
	echo "If your dynamic DNS provider is DuckDNS, enter your DUCKDNS_TOKEN:"
	read -rp "DuckDNS token: " -e duckdns_token

	[[ -n "${duckdns_token}" ]] && acme_dns_challenge_provider="duckdns"
elif [[ "${ssl_mode}" == "self-signed" ]]; then
	echo ""
	read -rp "Would you like to create and overwrite existing self-signed SSL certificates? (Y/N): " -e create_self_signed

	! [[ "${create_self_signed}" == [nN] || "${create_self_signed}" == [nN][oO] ]] \
		&& create_self_signed=true || create_self_signed=false
elif [[ "${ssl_mode}" == "http-acme-eab" ]]; then
	echo ""
	echo "Please enter the credentials for your ACME External Account Binding (EAB):"
	read -rp "ACME CA Server: " -e acme_caserver
	read -rp "ACME EAB key ID: " -e acme_eab_kid
	read -rp "ACME EAB encoded HMAC: " -e acme_eab_hmacencoded
else
	echo "Unsupported SSL mode: ${ssl_mode}"
	exit 1
fi

echo ""
read -rp "Is this a production deployment? (Y/N): " -e production
if ! [[ $production == [nN] || $production == [nN][oO] ]]; then
	secure_credentials=true
	allow_registration=false
	deploy_mode="production"
else
	allow_registration=true
	deploy_mode="development"

	echo ""
	echo "This is NOT a production deployment: You can choose if admin credentials for the various services shall be defaults or generated secure credentials."
	read -rp "Shall admin credentials be secure? (Y/N): " -e secure_creds

	! [[ $secure_creds == [nN] || $secure_creds == [nN][oO] ]] \
		&& secure_credentials=true || secure_credentials=false
fi

echo ""
echo "Enter your NVIDIA NGC API key (https://ngc.nvidia.com/setup/api-key), if any:"
read -rp "NVIDIA NGC API key: " -e nvidia_ngc_api_key

echo ""
echo "Enter comma-separated list of GPU IDs as shown by 'nvidia-smi -L', if any:"
read -rp "GPU IDs: " -e gpus

echo ""
echo "Enter a fine-grained GitHub personal access token with API access (https://bit.ly/3OlFBFo), if any:"
read -rp "Fine-grained GitHub personal access token: " -e github_token

echo ""
echo "Enter flags to use with 'docker compose down' (e.g. -v to delete volumes):"
read -rp "Flags for 'docker compose down': " -e compose_down_flags

echo ""
echo "Please enter the password for your EDC keystore"
read -rp "EDC keystore password: " -e edc_keystore_password

generatePassword() {
	< /dev/urandom tr -dc A-Za-z0-9 | head -c20
}

default_user="agri-gaia"
compose_profiles="edge,annotation,semantics,monitoring,edc,triton"

cat <<EOF > "${env_filepath}"
AG_GIT_BASE_URL=${git_base_url}
AG_GIT_ORGANIZATION=${git_organization}
AG_GIT_REPOSITORY_PLATFORM=${git_repository_platform}
AG_GIT_BRANCH_PLATFORM=${git_branch_platform}
AG_GIT_REPOSITORY_BACKEND=${git_repository_backend}
AG_GIT_BRANCH_BACKEND=${git_branch_backend}
AG_GIT_REPOSITORY_FRONTEND=${git_repository_frontend}
AG_GIT_BRANCH_FRONTEND=${git_branch_frontend}
AG_GIT_PUBLIC_REPOSITORIES=${git_public_repositories}
AG_PROJECT_BASE_URL=${project_base_url}
AG_SOURCE_DIR=/opt/agri-gaia

AG_DEPLOY_MODE=${deploy_mode}
AG_COMPOSE_DOWN_FLAGS=${compose_down_flags}
AG_COMPOSE_PROFILES=${compose_profiles}
AG_SECURE_CREDENTIALS=${secure_credentials}
AG_SSL_MODE=${ssl_mode}
AG_CREATE_SELF_SIGNED=${create_self_signed}
AG_ALLOW_REGISTRATION=${allow_registration}
AG_GPUS=${gpus}

AG_VOLUMES_TO_REMOVE=
AG_REMOVE_SOURCE_FILES=false
AG_REMOVE_STOPPED_CONTAINERS=false
AG_REMOVE_UNMANAGED_CONTAINERS=false

AG_LETSENCRYPT_TOKEN=${duckdns_token}
AG_ACME_EMAIL=${acme_email}
AG_ACME_CASERVER=${acme_caserver}
AG_ACME_EAB_KID=${acme_eab_kid}
AG_ACME_EAB_HMACENCODED=${acme_eab_hmacencoded}
AG_ACME_DNS_CHALLENGE_PROVIDER=${acme_dns_challenge_provider}

AG_TRAEFIK_USER=${default_user}
AG_TRAEFIK_PASSWORD=$(generatePassword)

AG_KEYCLOAK_USER=${default_user}
AG_KEYCLOAK_PASSWORD=$(generatePassword)
AG_KEYCLOAK_DB_USER=${default_user}
AG_KEYCLOAK_DB_PASSWORD=$(generatePassword)
AG_REALM_SERVICE_ACCOUNT_PASSWORD=$(generatePassword)

AG_MINIO_ROOT_USER=${default_user}
AG_MINIO_ROOT_PASSWORD=$(generatePassword)

AG_EDC_KEYSTORE_PASSWORD=${edc_keystore_password}

AG_EDC_ENDPOINT_PASSWORD=$(generatePassword)
AG_PONTUSX_ENDPOINT_PASSWORD=$(generatePassword)

AG_FUSEKI_ADMIN_USER=${default_user}
AG_FUSEKI_ADMIN_PASSWORD=$(generatePassword)

AG_BACKEND_POSTGRES_USER=${default_user}
AG_BACKEND_POSTGRES_PASSWORD=$(generatePassword)
AG_BACKEND_POSTGIS_USER=${default_user}
AG_BACKEND_POSTGIS_PASSWORD=$(generatePassword)

AG_CVAT_SUPERUSER_PASSWORD=$(generatePassword)
AG_GRAFANA_ADMIN_PASSWORD=$(generatePassword)
AG_PORTAINER_ADMIN_PASSWORD=$(generatePassword)

AG_GITHUB_TOKEN=${github_token}
AG_NVIDIA_NGC_API_KEY=${nvidia_ngc_api_key}
EOF

cat "${env_filepath}"