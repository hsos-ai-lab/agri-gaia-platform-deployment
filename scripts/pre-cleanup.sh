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

compose_project_name=$(grep COMPOSE_PROJECT_NAME "${AG_SOURCE_DIR}/platform/.env" | cut -f 2 -d '=')

remove_dangling_volumes_cmd="/bin/bash ${AG_DEPLOY_SCRIPT_DIR}/cron/remove-dangling-volumes.sh ${compose_project_name}"
eval "${remove_dangling_volumes_cmd}"

# Remove dangling volumes regulary (every 3 hours) via cron if platform is running
if ! crontab -l | grep -q "remove-dangling-volumes.sh"; then
    crontab -l \
        | { cat; echo "0 */3 * * * ${remove_dangling_volumes_cmd}"; } \
        | crontab -
fi

# Make sure to remove the network associated with the Docker Compose project.
# This should happen automatically on 'docker compose down' but might fail if active connections exist
compose_project_network="${compose_project_name}_network"
network_id=$(docker network ls --filter name="${compose_project_network}" -q)
if [[ -n "${network_id}" ]]; then
    docker network inspect "${compose_project_network}" \
        | jq -r '.[0].Containers | keys[]' \
        | xargs -I {} docker network disconnect -f "${compose_project_network}" {}
    docker network rm ${network_id}
else
    echo "No network to remove!"
fi

# We manually delete every container and volume matching the project name, because we create additional volumes on runtime for each user
containers=$(docker container ls -a --filter name="${compose_project_name}" -q)

if [[ -n "${containers}" ]]; then
    docker container rm ${containers}
else
    echo "No Containers to remove!"
fi

if [[ "${AG_REMOVE_UNMANAGED_CONTAINERS}" == true ]]; then
    docker ps --filter name="^nuclio-" -q | xargs -I {} docker stop {}
    docker ps -a --filter name="^nuclio-" -q | xargs -I {} docker rm --force {}

    docker ps --filter name="^${compose_project_name}-jupyter-" -q | xargs -I {} docker stop {}
    docker ps -a --filter name="^${compose_project_name}-jupyter-" -q | xargs -I {} docker rm --force {}
fi

if [[ "${AG_COMPOSE_DOWN_FLAGS}" == *"-v"* ]]; then
    volumes=$(docker volume ls --filter name="${compose_project_name}" -q)

    if [[ -n "${volumes}" ]]; then
        docker volume rm --force ${volumes}
    else
        echo "No volumes to remove!"
    fi

    # Avoid "volume is in use" by unmanaged container if container is not removed
    if [[ "${AG_REMOVE_UNMANAGED_CONTAINERS}" == true ]]; then
        # Remove unmanaged volumes
        docker volume ls --filter name="^nuclio-" -q \
            | xargs -I {} docker volume rm --force {}
    fi
fi
