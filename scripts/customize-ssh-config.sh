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

ssh_config="${HOME}/.ssh/config"
[[ ! -f "${ssh_config}" ]] && touch "${ssh_config}"

if ! grep -q "Host platform.${AG_GIT_BASE_URL}" "${ssh_config}"; then
cat >> "${ssh_config}" <<EOL

Host platform.${AG_GIT_BASE_URL}
	HostName ${AG_GIT_BASE_URL}
	User git
	IdentityFile ${HOME}/.ssh/agri-gaia/platform/id_ed25519
	IdentitiesOnly yes
EOL
fi

if ! grep -q "Host backend.${AG_GIT_BASE_URL}" "${ssh_config}"; then
cat >> "${ssh_config}" <<EOL

Host backend.${AG_GIT_BASE_URL}
	HostName ${AG_GIT_BASE_URL}
	User git
	IdentityFile ${HOME}/.ssh/agri-gaia/backend/id_ed25519
	IdentitiesOnly yes
EOL
fi

if ! grep -q "Host frontend.${AG_GIT_BASE_URL}" "${ssh_config}"; then
cat >> "${ssh_config}" <<EOL

Host frontend.${AG_GIT_BASE_URL}
	HostName ${AG_GIT_BASE_URL}
	User git
	IdentityFile ${HOME}/.ssh/agri-gaia/frontend/id_ed25519
	IdentitiesOnly yes
EOL
fi

chmod 644 "${ssh_config}"

ssh_knwon_hosts="${HOME}/.ssh/known_hosts"
ssh-keyscan -t rsa "${AG_GIT_BASE_URL}" | tee -a "${ssh_knwon_hosts}"
ssh-keyscan -t rsa github.com | tee -a "${ssh_knwon_hosts}"