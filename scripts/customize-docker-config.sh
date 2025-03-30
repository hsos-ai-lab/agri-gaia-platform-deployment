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

[[ -z "${AG_NVIDIA_NGC_API_KEY}" ]] && { echo "No NVIDIA NGC API key provided."; exit 0; }

sed -i "s/NVIDIA_NGC_API_KEY=.*/NVIDIA_NGC_API_KEY=${AG_NVIDIA_NGC_API_KEY}/g" "${AG_SOURCE_DIR}/platform/.env"

docker_config_dirs=("${HOME}/.docker")

for docker_config_dir in "${docker_config_dirs[@]}"
do
    mkdir -p "${docker_config_dir}"
    cd "${docker_config_dir}" || exit 1

    [[ ! -f "config.json" ]] && echo "{}" > "config.json"
    nvidia_ngc_auth="$(echo -n '$oauthtoken:'"${AG_NVIDIA_NGC_API_KEY}" | base64 -w 0)"

    jq --arg nvidia_ngc_auth "${nvidia_ngc_auth}" '.auths."nvcr.io".auth = $nvidia_ngc_auth' config.json \
        | sponge config.json
done