#!/usr/bin/env bash
# See: https://docs.docker.com/engine/install/ubuntu/

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

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

mode="${1}"

if [[ "${mode}" == "install" ]]; then
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt-get remove -y $pkg;
    done

    # Add Docker's official GPG key:
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    xargs -a "${script_dir}/docker.txt" apt-get install -y

    systemctl enable --now docker

    docker --version
    docker compose version
    docker buildx version
elif [[ "${mode}" == "uninstall" ]]; then
    xargs -a "${script_dir}/docker.txt" apt-get remove -y
    rm /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc
    apt-get update
else
    >&2 echo "Unknown mode '${mode}'. Usage: ${0} {install, remove}"; exit 1
fi
