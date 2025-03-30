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


usage() {
    echo "Usage: ${0} -d agri-gaia.{dev, localhost, ...} -o <output_path> [ -f (force) ]"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

FORCE=false
while getopts "d:o:f" opt; do
  case "${opt}" in
    d) DOMAIN="${OPTARG}";;
    o) OUTPUT_PATH="${OPTARG}";;
    f) FORCE=true;;
    \?)
      >&2 echo "Option '-$OPTARG' is not a valid option."
      usage
      exit 1
      ;;
    :)
      >&2 echo "Option '-$OPTARG' needs an argument."
      usage
      exit 2
      ;;
  esac
done

[[ -z "${OUTPUT_PATH}" ]] && OUTPUT_PATH="."
mkdir -p "${OUTPUT_PATH}"

if [[ "${FORCE}" != true ]] && [[ "${FORCE}" != false ]]; then
  echo "-f (force) is not a boolean value."
  exit 3
fi

if ls -A "${OUTPUT_PATH}" | grep -q "${DOMAIN}" && [[ "${FORCE}" == false ]]; then
  echo "Certificates for ${DOMAIN} already exist."
  exit 4
fi

curve="secp384r1"
# See: ERR_CERT_VALIDITY_TOO_LONG (https://stackoverflow.com/a/65239775)
days=397
subject="/CN=*.${DOMAIN}/O=Osnabrueck University of Applied Sciences/OU=Faculty of Engineering and Computer Science/L=Osnabrueck/ST=Lower Saxony/C=DE"

# See: https://stackoverflow.com/a/60516812
#################################
# Become a Certificate Authority
#################################

# Generate private key
openssl ecparam -name "${curve}" -genkey \
  -out "${OUTPUT_PATH}/ca.${DOMAIN}.key"

# Generate root certificate
openssl req -x509 -new -nodes \
  -key "${OUTPUT_PATH}/ca.${DOMAIN}.key" \
  -sha384 -days "${days}" \
  -subj "${subject}" \
  -out "${OUTPUT_PATH}/ca.${DOMAIN}.crt"

#########################
# Create CA-signed certs
#########################

# Generate a private key
openssl ecparam -name "${curve}" -genkey \
  -out "${OUTPUT_PATH}/${DOMAIN}.key"

# Create a certificate-signing request
openssl req -new \
  -key "${OUTPUT_PATH}/${DOMAIN}.key" \
  -subj "${subject}" \
  -out "${OUTPUT_PATH}/${DOMAIN}.csr"

cat <<EOF > "${OUTPUT_PATH}/${DOMAIN}.ext"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
extendedKeyUsage=serverAuth,clientAuth
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${DOMAIN} 
DNS.2 = *.${DOMAIN} 
EOF

# Create the signed certificate
openssl x509 -req \
  -in "${OUTPUT_PATH}/${DOMAIN}.csr" \
  -CA "${OUTPUT_PATH}/ca.${DOMAIN}.crt" \
  -CAkey "${OUTPUT_PATH}/ca.${DOMAIN}.key" -CAcreateserial \
  -out "${OUTPUT_PATH}/${DOMAIN}.crt" -days "${days}" -sha384 \
  -extfile "${OUTPUT_PATH}/${DOMAIN}.ext"
