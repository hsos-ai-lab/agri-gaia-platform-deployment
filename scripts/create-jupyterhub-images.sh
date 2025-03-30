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

jupyterhub_images_path="${AG_SOURCE_DIR}/platform/services/jupyterhub/images"
platform_env_filepath="${AG_SOURCE_DIR}/platform/.env"

jupyterhub_version="$(grep "JUPYTERHUB_VERSION=" "${platform_env_filepath}" | cut -d "=" -f 2)"

cd "${jupyterhub_images_path}" || exit 1

/bin/bash "${jupyterhub_images_path}/build-cpu-images.sh" "${jupyterhub_version}"

if [[ "${AG_GPUS_AVAILABLE}" == true ]] && [[ -n "${AG_GPUS}" ]]; then
    sed -i "s/JUPYTERHUB_USE_NVIDIA_RUNTIME=.*/JUPYTERHUB_USE_NVIDIA_RUNTIME=1/g" "${platform_env_filepath}"
    jupyterhub_ngc_image_tag="$(grep "JUPYTERHUB_NGC_IMAGE_TAG=" "${platform_env_filepath}" | cut -d "=" -f 2)"
    /bin/bash "${jupyterhub_images_path}/build-gpu-images.sh" "${jupyterhub_version}" "${jupyterhub_ngc_image_tag}"
fi