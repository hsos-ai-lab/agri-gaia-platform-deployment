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

AG_GIT_BRANCH_PLATFORM="${1}"
AG_VOLUMES_TO_REMOVE="${2}"

deploy_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "${deploy_dir}" || exit 1

session_name="ag-deploy"

screen -ls \
	| grep "${session_name}" \
	| awk -F. '{print $1}' \
	| xargs -I {} screen -S {} -X quit

deploy_timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"
screen -A -dm -S "${session_name}" \
	bash -c "stdbuf -o 0 ./scripts/deploy.sh ${AG_GIT_BRANCH_PLATFORM} ${AG_VOLUMES_TO_REMOVE} 2>&1 | tee logs/${deploy_timestamp}.log" &
