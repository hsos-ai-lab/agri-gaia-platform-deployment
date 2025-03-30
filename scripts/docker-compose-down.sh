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

compose_down_cmd="COMPOSE_PROFILES=${AG_COMPOSE_PROFILES} docker compose down"
[[ -n "${AG_COMPOSE_DOWN_FLAGS}" ]] && compose_down_cmd="${compose_down_cmd} ${AG_COMPOSE_DOWN_FLAGS}"
compose_down_cmd="${compose_down_cmd} --remove-orphans"

echo "${compose_down_cmd}"
eval "${compose_down_cmd}"

[[ -n "${AG_VOLUMES_TO_REMOVE}" && "${AG_COMPOSE_DOWN_FLAGS}" != *"-v"* ]] \
  && docker volume rm --force "$(echo "${AG_VOLUMES_TO_REMOVE}" | tr "," " ")"