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

cd "${AG_SOURCE_DIR}/platform/secrets/certs/issued" || exit 1

# Rename any *.crt and *.key files to start with AG_PROJECT_BASE_URL
[[ ! -f "${AG_PROJECT_BASE_URL}.crt" ]] && mv ./*.crt "${AG_PROJECT_BASE_URL}.crt"
[[ ! -f "${AG_PROJECT_BASE_URL}.key" ]] && mv ./*.key "${AG_PROJECT_BASE_URL}.key"

# Check if issued certificate and key with AG_PROJECT_BASE_URL as prefix exist.
if [[ ! -f "${AG_PROJECT_BASE_URL}.crt" ]] || [[ ! -f "${AG_PROJECT_BASE_URL}.key" ]]; then
    >&2 echo "Issued certificate or key not found in directory '$(pwd)'."
    exit 2
fi
