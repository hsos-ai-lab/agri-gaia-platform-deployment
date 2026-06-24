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

if [[ "${AG_GPUS}" != "all" ]]; then
    num_gpus=$(("$(echo "${AG_GPUS}" | awk -F"," '{print NF-1}')" + 1))
    (("${num_gpus}" > "${AG_MAX_GPUS}")) \
        && { echo "More GPUs requested (${num_gpus}) than actually present (${AG_MAX_GPUS})."; exit 2; }
fi

cd "${AG_SOURCE_DIR}/platform" || exit 3

sed -i "s/GPUS=.*/GPUS=${AG_GPUS}/g" .env