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

mode="${1}"

if [[ "${mode}" == "install" ]]; then
    if command -v nvidia-smi &> /dev/null; then
        echo "Detected NVIDIA GPUs on host:"
        nvidia-smi -L
    else
        echo "Not installing nvidia-container-toolkit as no NVIDIA GPUs were detected on the host."
        exit 0
    fi

    if command -v nvidia-container-toolkit &> /dev/null; then
        echo "Not installing nvidia-container-toolkit as it is already installed."
        exit 0
    fi

    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
        && apt-get update \
        && apt-get install --no-install-recommends -y nvidia-container-toolkit \
        && apt-get autoremove -y

    nvidia-ctk runtime configure --runtime=docker
elif [[ "${mode}" == "remove" ]]; then
    if ! command -v nvidia-container-toolkit &> /dev/null; then
        echo "Not removing nvidia-container-toolkit as it is not installed."; exit 0
    fi

    apt-get remove -y nvidia-container-toolkit \
        && rm /etc/apt/sources.list.d/nvidia-container-toolkit.list
else
    >&2 echo "Unknown mode '${mode}'. Usage: ${0} {install, remove}"; exit 1
fi
