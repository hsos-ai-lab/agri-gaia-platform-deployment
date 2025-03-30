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
  echo "Usage: ${0} -b <git_branch> [-f <instances_file>] [-t <targets>] [-v <volumes_to_remove>] [-i <identity_file>]"
  echo "Example: ${0} -b development -f instances.json -t gpu0 -i ~/.ssh/agri-gaia-keypair/id_ed25519"
}

[[ $# -eq 0 ]] && { usage; exit 1; }

while getopts b:f:t:v:i: opt
do
  case "${opt}" in
    b) git_branch="${OPTARG}";;
    f) instances_file="${OPTARG}";;
    t) target_names="${OPTARG}";;
    v) volumes_to_remove="${OPTARG}";;
    i) identity_file="${OPTARG}";;
    \?)
      echo "Option '-$OPTARG' is not a valid option." >&2
      usage
      exit 2
      ;;
    : )
      echo "Option '-$OPTARG' needs an argument." >&2
      usage
      exit 3
      ;;
  esac
done

remote_deploy_dir="/opt/agri-gaia/deploy"
remote_deploy_filepath="${remote_deploy_dir}/deploy.sh"

[[ -z "${instances_file}" ]] && instances_file="instances.json"
[[ ! -f "${instances_file}" ]] && { echo "JSON file '${instances_file}' not found."; exit 4; }
[[ -z "${git_branch}" ]] && { echo "No git branch provided for deployment."; exit 5; }
[[ -z "${target_names}" ]] && target_names="$(jq -r 'keys | join(",")' "${instances_file}")"
[[ -z "${identity_file}" ]] && identity_file="${HOME}/.ssh/agri-gaia-keypair/id_ed25519"

remote_deploy_cmd="cd ${remote_deploy_dir} && git stash; git pull && /bin/bash ${remote_deploy_filepath} ${git_branch} ${volumes_to_remove}"

for target_name in $(echo "${target_names}" | tr "," "\n")
do
  target=$(jq -r --arg target_name "${target_name}" '.[$target_name]' "${instances_file}")

  [[ "${target}" == "null" ]] \
    && { echo "Skipping unknown deployment target '${target}'..."; continue; }

  host="$(echo "${target}" | jq -r '.host')"
  user="$(echo "${target}" | jq -r '.user')"
  ip="$(echo "${target}" | jq -r '.ip')"
  port="$(echo "${target}" | jq -r '.port')"
  proxy_command="$(echo "${target}" | jq -r '.proxy_cmd')"

  ssh_cmd_options="-o StrictHostKeyChecking=no"
  if [[ "${proxy_command}" != "null" && -n "${proxy_command}" ]]; then
    ssh_cmd_options="${ssh_cmd_options} -o ProxyCommand=\"${proxy_command}\""
    ssh_cmd="ssh ${ssh_cmd_options} -n -i ${identity_file} ${user}@${ip}"
  else
    ssh_cmd="ssh ${ssh_cmd_options} -n -p ${port} -i ${identity_file} ${user}@${ip}"
  fi

  docker_daemon_filepath="/etc/docker/daemon.json"
  ! eval "${ssh_cmd} test -f ${docker_daemon_filepath}" \
    && { echo "File ${docker_daemon_filepath} does not exist. Skipping deployment..."; continue; }

  cmd="${ssh_cmd} '${remote_deploy_cmd}'"
  echo "Redeploying to '${host}' using ${cmd}..."
  eval "${cmd}"

  echo "Done."
done
