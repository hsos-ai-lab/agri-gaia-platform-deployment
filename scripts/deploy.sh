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

echo "$(date +"%Y-%m-%d %H:%M:%S.%6N") - ${0}"

[[ "${EUID}" -ne 0 ]] && { echo "This script must be run as root or with sudo privileges."; exit 1; }
! command -v apt-get &> /dev/null && { echo "The apt package manager is not installed"; exit 2; }

set -a

AG_DEPLOY_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "${AG_DEPLOY_SCRIPT_DIR}" || exit 3

[[ ! -f .env ]] && { echo "No .env found for deployment. Run ./setup-env.sh first."; exit 4; }

source .env

# NOTE: This script allows 'redeploy-instances.sh' to override the following two values from the deployment .env:

# shellcheck disable=SC2034
[[ -n "${1}" ]] && AG_GIT_BRANCH_PLATFORM="${1}"

# shellcheck disable=SC2034
[[ -n "${2}" ]] && AG_VOLUMES_TO_REMOVE="${2}"

[[ -z "${AG_SOURCE_DIR}" ]] && AG_SOURCE_DIR="/opt/agri-gaia"
[[ ! -d "${AG_SOURCE_DIR}" ]] && { echo "Source directory '${AG_SOURCE_DIR}' does not exist."; exit 5; }
[[ ! -d "${AG_SOURCE_DIR}/secrets" ]] && { echo "Secrects directory '${AG_SOURCE_DIR}/secrets' does not exist."; exit 6; }
[[ -z "${AG_GIT_BASE_URL}" ]] && { echo "AG_GIT_BASE_URL is empty"; exit 7;}
[[ -z "${AG_PROJECT_BASE_URL}" ]] && { echo "AG_PROJECT_BASE_URL is empty"; exit 8;}

AG_GPUS="$(echo "${AG_GPUS}" | sed 's/,*$//g;s/^,*//g')"
AG_MAX_GPUS="$(command -v nvidia-smi &> /dev/null && nvidia-smi -L | wc -l)"

[[ -z "${AG_GIT_ORGANIZATION}" ]] && AG_GIT_ORGANIZATION="hsos-ai-lab"
[[ -z "${AG_GIT_REPOSITORY_PLATFORM}" ]] && AG_GIT_REPOSITORY_PLATFORM="agri-gaia-platform"
[[ -z "${AG_GIT_BRANCH_PLATFORM}" ]] && AG_GIT_BRANCH_PLATFORM="main"
[[ -z "${AG_GIT_REPOSITORY_BACKEND}" ]] && AG_GIT_REPOSITORY_BACKEND="agri-gaia-backend"
[[ -z "${AG_GIT_BRANCH_BACKEND}" ]] && AG_GIT_BRANCH_BACKEND="main"
[[ -z "${AG_GIT_REPOSITORY_FRONTEND}" ]] && AG_GIT_REPOSITORY_FRONTEND="agri-gaia-frontend"
[[ -z "${AG_GIT_BRANCH_FRONTEND}" ]] && AG_GIT_BRANCH_FRONTEND="main"

[[ -z "${AG_DEPLOY_MODE}" ]] &&  AG_DEPLOY_MODE="production"
[[ "${AG_DEPLOY_MODE}" != "development" && "${AG_DEPLOY_MODE}" != "production" ]] \
  && { echo "Unknown deploy_mode '${AG_DEPLOY_MODE}'."; exit 9; }
[[ -z "${AG_MAX_GPUS}" || "${AG_MAX_GPUS}" == "0" ]] && AG_GPUS_AVAILABLE=false || AG_GPUS_AVAILABLE=true
[[ -z "${AG_SSL_MODE}" ]] && AG_SSL_MODE="lets-encrypt-http"
[[ -z "${AG_CREATE_SELF_SIGNED}" ]] && AG_CREATE_SELF_SIGNED=false
[[ "${AG_ALLOW_REGISTRATION}" != true ]] && AG_ALLOW_REGISTRATION=false
[[ -z "${AG_COMPOSE_PROFILES}" ]] && AG_COMPOSE_PROFILES="edge,annotation,semantics,monitoring,edc"
[[ -z "${AG_REMOVE_UNMANAGED_CONTAINERS}" ]] && AG_REMOVE_UNMANAGED_CONTAINERS=false

set +a

if [[ "${AG_GIT_PUBLIC_REPOSITORIES}" == false ]]; then
  time ./customize-ssh-config.sh || exit 10
fi

time ./git-clone.sh || exit 11

set -a

printenv | grep "^AG_"

acme_ssl_mode() {
    [[ "${AG_SSL_MODE}" == "lets-encrypt-dns" \
    || "${AG_SSL_MODE}" == "lets-encrypt-http" \
    || "${AG_SSL_MODE}" == "http-acme-eab" ]] && return 0 || return 1
}

if [[ "${AG_SSL_MODE}" == "self-signed" ]]; then
    if [[ "${AG_CREATE_SELF_SIGNED}" == true ]]; then
        time ./create-self-signed-certs.sh || exit 12
    fi
elif [[ "${AG_SSL_MODE}" == "issued" ]]; then
    time ./check-issued-certs.sh || exit 13
elif acme_ssl_mode; then
    time ./customize-acme.sh || exit 14
else
  echo "Unsupported SSL mode: ${AG_SSL_MODE}"; exit 15
fi

time ./customize-docker-config.sh || exit 16
time ./customize-dynamic-config.sh || exit 17
[[ "${AG_SSL_MODE}" != "self-signed" ]] && { time ./customize-ssl-verification.sh || exit 18; }
time ./customize-project-base-url.sh || exit 19
[[ "${AG_SECURE_CREDENTIALS}" == true ]] && { time ./customize-credentials.sh || exit 20; }
time ./customize-keycloak-realm.sh || exit 21

[[ "${AG_GPUS_AVAILABLE}" == true && -n "${AG_GPUS}" ]] && { time ./customize-gpus.sh || exit 22; }

time ./docker-compose-down.sh
time ./pre-cleanup.sh || exit 23
time ./create-jupyterhub-images.sh || exit 24
time ./docker-compose-up.sh

if acme_ssl_mode; then
    time ./extract-acme-certs.sh || exit 25

    # Restart containers which are mounting extracted certs as volumes
    cd "${AG_SOURCE_DIR}/platform" \
        && COMPOSE_PROFILES="${AG_COMPOSE_PROFILES}" docker compose restart build_container \
        && cd - || exit 26
fi

time ./post-cleanup.sh || exit 27
