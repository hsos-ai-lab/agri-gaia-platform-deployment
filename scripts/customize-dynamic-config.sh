#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024 University of Applied Sciences Osnabrück
# SPDX-FileContributor: Andreas Schliebitz
# SPDX-FileContributor: Henri Graf
# SPDX-FileContributor: Jonas Tüpker
# SPDX-FileContributor: Lukas Hesse
# SPDX-FileContributor: Maik Fruhner
# SPDX-FileContributor: Prof. Dr.-Ing. Heiko Tapken
# SPDX-FileContributor: Tobias Wamhof
#
# SPDX-License-Identifier: AGPL-3.0-or-later

echo "$(date +"%Y-%m-%d %H:%M:%S.%6N") - ${0}"

cd "${AG_SOURCE_DIR}/platform/config/traefik" || exit 1
sed -i "s/agri-gaia.localhost/${AG_PROJECT_BASE_URL}/g" dynamic.yaml

# Add strict SNI checking for not self-signed certs and remove
# default certificate store if non-local certs are used (e. g. LetsEncrypt).
if [[ "${AG_SSL_MODE}" != "self-signed" ]]; then
  yq e -i '.tls.options.default.sniStrict = true' dynamic.yaml
  [[ "${AG_SSL_MODE}" != "issued" ]] && yq e -i 'del(.tls.stores)' dynamic.yaml
fi
