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

generate_random_token() {
    local length="${1}"
    local seed="${2}"

    [[ -z "${length}" ]] && length=64

    local token
    local machine_id

    machine_id="$(cat /etc/machine-id)"
    if [[ -z "${machine_id}" ]] || [[ -z "${seed}" ]]; then
        token="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w "${length}" | head -n 1)"
    else
        local hash hex truncated_hex random_seed
        hash="$(echo -n "${machine_id}${seed}" | sha256sum)"
        hex="${hash%% *}"
        truncated_hex="${hex:0:15}"
        random_seed="$(printf "%d\n" "0x${truncated_hex}")"
        token="$(makepasswd --chars "${length}" --randomseed "${random_seed}")"
    fi

    echo "${token}"
}

# Tokens randomly regenerated on each deployment
session_secret_key="$(generate_random_token 64)"
agbot_token="$(generate_random_token 64)"
backend_registry_token="$(generate_random_token 64)"
backend_openid_client_secret="$(generate_random_token 64)"

# Htpasswd
traefik_htpasswd=$(echo "${AG_TRAEFIK_PASSWORD}" | htpasswd -niB "${AG_TRAEFIK_USER}" | cut -f 2 -d ':')
realm_service_account_htpasswd=$(echo "${AG_REALM_SERVICE_ACCOUNT_PASSWORD}" | htpasswd -niB service-account-realm | cut -f 2 -d ':')

cd "${AG_SOURCE_DIR}/platform" || exit 1

# Customize platform/.env (cwd = $AG_SOURCE_DIR/platform)
sed -i "s/TRAEFIK_USER=.*/TRAEFIK_USER='${AG_TRAEFIK_USER}'/g" .env
sed -i "s|TRAEFIK_HTPASSWD=.*|TRAEFIK_HTPASSWD='${traefik_htpasswd}'|g" .env

sed -i "s/KEYCLOAK_USER=.*/KEYCLOAK_USER=${AG_KEYCLOAK_USER}/g" .env
sed -i "s/KEYCLOAK_PASSWORD=.*/KEYCLOAK_PASSWORD=${AG_KEYCLOAK_PASSWORD}/g" .env
sed -i "s/KEYCLOAK_DB_USER=.*/KEYCLOAK_DB_USER=${AG_KEYCLOAK_DB_USER}/g" .env
sed -i "s/KEYCLOAK_DB_PASSWORD=.*/KEYCLOAK_DB_PASSWORD=${AG_KEYCLOAK_DB_PASSWORD}/g" .env

sed -i "s/REALM_SERVICE_ACCOUNT_PASSWORD=.*/REALM_SERVICE_ACCOUNT_PASSWORD=${AG_REALM_SERVICE_ACCOUNT_PASSWORD}/g" .env
sed -i "s|REALM_SERVICE_ACCOUNT_HTPASSWD=.*|REALM_SERVICE_ACCOUNT_HTPASSWD='${realm_service_account_htpasswd}'|g" .env

sed -i "s/MINIO_ROOT_USER=.*/MINIO_ROOT_USER=${AG_MINIO_ROOT_USER}/g" .env
sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=${AG_MINIO_ROOT_PASSWORD}/g" .env

sed -i "s/FUSEKI_ADMIN_USER=.*/FUSEKI_ADMIN_USER=${AG_FUSEKI_ADMIN_USER}/g" .env
sed -i "s/FUSEKI_ADMIN_PASSWORD=.*/FUSEKI_ADMIN_PASSWORD=${AG_FUSEKI_ADMIN_PASSWORD}/g" .env

sed -i "s/BACKEND_POSTGRES_USER=.*/BACKEND_POSTGRES_USER=${AG_BACKEND_POSTGRES_USER}/g" .env
sed -i "s/BACKEND_POSTGRES_PASSWORD=.*/BACKEND_POSTGRES_PASSWORD=${AG_BACKEND_POSTGRES_PASSWORD}/g" .env
sed -i "s/BACKEND_REGISTRY_TOKEN=.*/BACKEND_REGISTRY_TOKEN=${backend_registry_token}/g" .env
sed -i "s/BACKEND_POSTGIS_USER=.*/BACKEND_POSTGIS_USER=${AG_BACKEND_POSTGIS_USER}/g" .env
sed -i "s/BACKEND_POSTGIS_PASSWORD=.*/BACKEND_POSTGIS_PASSWORD=${AG_BACKEND_POSTGIS_PASSWORD}/g" .env

sed -i "s/CVAT_SUPERUSER_PASSWORD=.*/CVAT_SUPERUSER_PASSWORD=${AG_CVAT_SUPERUSER_PASSWORD}/g" .env
sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${AG_GRAFANA_ADMIN_PASSWORD}/g" .env

sed -i "s/BACKEND_OPENID_CLIENT_SECRET=.*/BACKEND_OPENID_CLIENT_SECRET=${backend_openid_client_secret}/g" .env
sed -i "s/AGBOT_TOKEN=.*/AGBOT_TOKEN=${agbot_token}/g" .env

sed -i "s/FUSEKI_ADMIN_USER=.*/FUSEKI_ADMIN_USER=${AG_FUSEKI_ADMIN_USER}/g" .env
sed -i "s/FUSEKI_ADMIN_PASSWORD=.*/FUSEKI_ADMIN_PASSWORD=${AG_FUSEKI_ADMIN_PASSWORD}/g" .env

sed -i "s/PORTAINER_ADMIN_PASSWORD=.*/PORTAINER_ADMIN_PASSWORD=${AG_PORTAINER_ADMIN_PASSWORD}/g" .env
sed -i "s/GITHUB_TOKEN=.*/GITHUB_TOKEN=${AG_GITHUB_TOKEN}/g" .env

sed -i "s/CONNECTOR_PASSWORD=.*/CONNECTOR_PASSWORD=${AG_EDC_ENDPOINT_PASSWORD}/g" .env
sed -i "s/PONTUSX_PASSWORD=.*/PONTUSX_PASSWORD=${AG_PONTUSX_ENDPOINT_PASSWORD}/g" .env

sed -i "s/KEYSTORE_PASSWORD=.*/KEYSTORE_PASSWORD=${AG_EDC_KEYSTORE_PASSWORD}/g" .env

# Customize services/backend/.env (cwd = $AG_SOURCE_DIR/platform/services/backend)
cd services/backend || exit 2

sed -i "s/SESSION_SECRET_KEY=.*/SESSION_SECRET_KEY=${session_secret_key}/g" .env
