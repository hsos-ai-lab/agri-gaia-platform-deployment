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

cd "${AG_SOURCE_DIR}/platform" || exit 1

if [[ "${AG_DEPLOY_MODE}" == "production" ]]; then
    override_name="prod"
elif [[ "${AG_DEPLOY_MODE}" == "development" ]]; then
    override_name="override"
else
    echo "Unknown deploy_mode '${AG_DEPLOY_MODE}'."; exit 2
fi

overrides="-f docker-compose.yml -f docker-compose.${override_name}.yml -f docker-compose-overrides/${AG_SSL_MODE}.yml"
[[ "${AG_GPUS_AVAILABLE}" == true ]] && overrides="${overrides} -f docker-compose-overrides/backend-gpus.yml"

compose_up_cmd="COMPOSE_PROFILES=${AG_COMPOSE_PROFILES} docker compose ${overrides} up -d --build"

echo "${compose_up_cmd}"
eval "${compose_up_cmd}"
