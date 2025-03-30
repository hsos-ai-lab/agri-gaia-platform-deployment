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

compose_project_name="${1}"

[[ -z "${compose_project_name}" ]] && exit 1

# Remove all dangling volumes not starting with compose_project_name
if docker compose ls \
  | awk 'NR>1 {print $1" "$2}' \
  | grep -q "${compose_project_name} running"; then
	docker volume ls -q -f dangling=true \
		| grep -v "${compose_project_name}" \
		| xargs -I {} docker volume rm {}
fi
