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

cd "${AG_SOURCE_DIR}/platform/services/keycloak/realm-export" || exit 1

sed -i "s/test-realm/${AG_KEYCLOAK_REALM}/g" ${AG_SOURCE_DIR}/platform/.env

if [[ "${AG_DEPLOY_MODE}" == "development" ]]; then
    sed -i "s/test-realm/${AG_KEYCLOAK_REALM}/g" ${AG_SOURCE_DIR}/platform/services/backend/agri_gaia_backend/services/portainer/portainer_api.py
    sed -i "s/test-realm/${AG_KEYCLOAK_REALM}/g" ${AG_SOURCE_DIR}/platform/services/frontend/public/keycloak.json
fi

jq \
    --argjson registrationAllowed "${AG_ALLOW_REGISTRATION}" \
    '.registrationAllowed = $registrationAllowed' \
    realm-export.json > tmp && \
    mv tmp realm-export.json
