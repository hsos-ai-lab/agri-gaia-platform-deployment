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

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

mode="${1}"

if [[ "${mode}" == "install" ]]; then
    apt-get update
    xargs -a "${script_dir}/utilities.txt" apt-get install -y --no-install-recommends

    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq \
        && chmod +x /usr/bin/yq

    systemctl enable --now cron
elif [[ "${mode}" == "remove" ]]; then
    xargs -a "${script_dir}/utilities.txt" apt-get remove -y
    rm /ust/bin/yq
else
    >&2 echo "Unknown mode '${mode}'. Usage: ${0} {install, remove}" && exit 1
fi
