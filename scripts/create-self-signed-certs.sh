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

create_wildcard_cert_path="${AG_DEPLOY_SCRIPT_DIR}/third-party/create-wildcard-certificate.sh"
self_signed_certs_path="${AG_SOURCE_DIR}/platform/secrets/certs/self-signed"

rm "${self_signed_certs_path}/*"
/bin/bash "${create_wildcard_cert_path}" \
    -d "${AG_PROJECT_BASE_URL}" \
    -o "${self_signed_certs_path}" \
    -f
