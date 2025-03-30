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

dump_acme_path="${AG_DEPLOY_SCRIPT_DIR}/third-party/dump-acme.sh"

cd "${AG_SOURCE_DIR}/platform/secrets/certs/acme" || exit 1

/bin/bash "${dump_acme_path}" acme.json . \
    && chmod -R 644 ssl/* \
    && mv ssl/* . \
    && rm -rf ssl

if ! crontab -l | grep -q "${0}"; then
    crontab -l \
        | { cat; echo "0 * * * * /bin/bash ${AG_DEPLOY_SCRIPT_DIR}/extract-acme-certs.sh ${AG_SOURCE_DIR} ${AG_PROJECT_BASE_URL} ${AG_SSL_MODE}"; } \
        | crontab -
fi