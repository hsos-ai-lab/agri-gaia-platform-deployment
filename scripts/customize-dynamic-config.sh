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

cd "${AG_SOURCE_DIR}/platform/services/traefik" || exit 1
sed -i "s/agri-gaia.localhost/${AG_PROJECT_BASE_URL}/g" dynamic.yaml

# Add strict SNI checking for non self-signed certs and remove
# default certificate store if non-local certs are used (e. g. LetsEncrypt).
if [[ "${AG_SSL_MODE}" != "self-signed" ]]; then
    add_strict_sni_check=true
    if [[ "${AG_SSL_MODE}" == "issued" ]]; then
        issued_cert_path="${AG_SOURCE_DIR}/platform/secrets/certs/issued/${AG_PROJECT_BASE_URL}.crt"
        san_count="$(openssl x509 -in "${issued_cert_path}" -text -noout \
            | grep -A 1 "Subject Alternative Name" \
            | grep -o "DNS:" \
            | wc -l)"
        # Do not add strict SNI checking for multi domain certificate
        [[ "${san_count}" -gt 1 ]] && add_strict_sni_check=false
    fi
    
    if [[ "${add_strict_sni_check}" == true ]]; then
        yq e -i '.tls.options.default.sniStrict = true' dynamic.yaml
    fi

    if [[ "${AG_SSL_MODE}" != "issued" ]]; then
        yq e -i 'del(.tls.stores)' dynamic.yaml
    fi
fi
