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

set -e

DOMAIN="${1}"
OUTPUT_PATH="${2}"

if [[ -z "${DOMAIN}" ]]; then
    >&2 echo "No domain provided for generation of self-singed certificate."
    exit 1
fi

[[ -z "${OUTPUT_PATH}" ]] && OUTPUT_PATH="."
OUTPUT_PATH="${OUTPUT_PATH%/}"
mkdir -p "${OUTPUT_PATH}"

curve="secp384r1"
# See: ERR_CERT_VALIDITY_TOO_LONG (https://stackoverflow.com/a/65239775)
days=397
subject="/CN=${DOMAIN}/O=Osnabrueck University of Applied Sciences/OU=Faculty of Engineering and Computer Science/L=Osnabrueck/ST=Lower Saxony/C=DE"

# Generate private key
openssl ecparam -name "${curve}" -genkey \
  -out "${OUTPUT_PATH}/${DOMAIN}.key"

# Create a certificate-signing request
openssl req -new \
  -key "${OUTPUT_PATH}/${DOMAIN}.key" \
  -subj "${subject}" \
  -out "${OUTPUT_PATH}/${DOMAIN}.csr"

# Create the signed certificate
openssl x509 -req \
  -in "${OUTPUT_PATH}/${DOMAIN}.csr" \
  -signkey "${OUTPUT_PATH}/${DOMAIN}.key" \
  -out "${OUTPUT_PATH}/${DOMAIN}.crt" \
  -days "${days}" \
  -sha384

cat "${OUTPUT_PATH}/${DOMAIN}.crt" "${OUTPUT_PATH}/${DOMAIN}.key" > "${OUTPUT_PATH}/${DOMAIN}.pem"