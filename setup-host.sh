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

# Run this script with sudo privileges
[[ "${EUID}" -ne 0 ]] \
    && { echo "This script must be run as root or with sudo privileges."; exit 1; }

setup_host_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "${setup_host_script_dir}" || exit 2

env_filepath="scripts/.env"
[[ ! -f ${env_filepath} ]] && { echo "No .env '${env_filepath}' found for host setup. Run ./setup-env.sh first."; exit 3; }

set -a
source "${env_filepath}"
set +a

printenv | grep "^AG_"

mkdir -p "${AG_SOURCE_DIR}"

packages_path="./packages"
restart_docker=false

/bin/bash "${packages_path}/utilities.sh" install || exit 4
/bin/bash "${packages_path}/docker.sh" install || exit 5

docker_config_dir="${HOME}/.docker"
mkdir -p "${docker_config_dir}"

docker_config_file="${docker_config_dir}/config.json"
[[ ! -f "${docker_config_file}" ]] && echo "{}" > "${docker_config_file}"

if [[ "${AG_SSL_MODE}" == "self-signed" ]]; then
    docker_daemon_conf="/etc/docker/daemon.json"

    [[ ! -f "${docker_daemon_conf}" || ! -s "${docker_daemon_conf}" ]] && echo "{}" > "${docker_daemon_conf}"

    [[ $(jq 'has("insecure-registries")' "${docker_daemon_conf}") == "false" ]] \
        && jq '. += {"insecure-registries": []}' "${docker_daemon_conf}" \
        | sponge "${docker_daemon_conf}"

    if [[ $(jq --arg registry_url "registry.${AG_PROJECT_BASE_URL}" '."insecure-registries"|any(. == $registry_url)' "${docker_daemon_conf}") == "false" ]]; then
        jq --arg registry_url "registry.${AG_PROJECT_BASE_URL}" '."insecure-registries" += [$registry_url]' "${docker_daemon_conf}" \
        | sponge "${docker_daemon_conf}"
        restart_docker=true
    fi
fi

# Detect GPUs and install NVIDIA Container Toolkit if needed
max_gpus="$(command -v nvidia-smi &> /dev/null && nvidia-smi -L | wc -l)"
nvidia_container_toolkit_installed="$({ command -v nvidia-container-toolkit &> /dev/null && echo true; } || echo false)"

[[ -z "${max_gpus}" || "${max_gpus}" == "0" ]] && gpus_available=false || gpus_available=true

if [[ "${gpus_available}" == true && "${nvidia_container_toolkit_installed}" == false ]]; then
    /bin/bash "${packages_path}/nvidia-container-toolkit.sh" install || exit 7
    restart_docker=true

    # See: https://github.com/NVIDIA/nvidia-docker/issues/1730
    create_symlinks_cmd="/usr/bin/nvidia-ctk system create-dev-char-symlinks --create-all"

cat > /lib/udev/rules.d/71-nvidia-dev-char.rules <<EOF
ACTION=="add", DEVPATH=="/bus/pci/drivers/nvidia", RUN+="${create_symlinks_cmd}"
EOF

    eval "${create_symlinks_cmd}"
fi

# Restart th Docker Daemon for changes to take effect
[[ "${restart_docker}" == true ]] && systemctl restart docker
