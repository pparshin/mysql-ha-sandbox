#!/bin/bash

set -e

# Enable pretty logger.
function log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $(printf "%s" "$@")"
}

log "[info] orchestrator executed a master recovery process and hook is triggered"

moveVipScriptPath=/usr/local/scripts/orch_vip.sh

# Ensure that all prerequirements is satisfied.
## Does required script to move VIP exist?
if [ ! -x "${moveVipScriptPath}" ]; then
  log "[fatal] required script is not executable or found: \"${moveVipScriptPath}\"!"
  exit 1
fi

# This arguments are passed from orchestrator.
failureType=${1}
failureClusterAlias=${2}
oldMaster=${3}
newMaster=${4}

# SSH options used to connect to servers when moving VIP.
sshOptions="-i /root/.ssh/orchestrator_rsa -o ConnectTimeout=5"

# Where "db_test" is the name of the cluster,
# "172.20.0.200" is the VIP on this cluster,
# "172.20.0.1" is the gateway used to update by arping,
# "root" is the SSH user.
#
# If we have multiple clusters, we have to add more arrays like this with the cluster details.
db_test=("172.20.0.200" "172.20.0.1" root)

# Failure types which we should recover from.
# https://github.com/github/orchestrator/blob/master/docs/failure-detection.md
failureTypes=("DeadMaster" "DeadMasterAndSomeSlaves")

if [[ " ${failureTypes[@]} " =~ " ${failureType} " ]]; then

  array=${failureClusterAlias}
  IP=$array[0]
  gateway=$array[1]
  user=$array[2]

  if [[ -n ${!IP} ]]; then
    log "[info] recovering from: ${failureType}"
    log "[info] old master is: ${oldMaster}"
    log "[info] new master is: ${newMaster}"

    log "[info] exec: ${moveVipScriptPath} -n ${newMaster} -s \"${sshOptions}\" -I ${!IP} -u ${!user} -g ${!gateway} -o ${oldMaster}"
    "${moveVipScriptPath}" -n "${newMaster}" -s "${sshOptions}" -I "${!IP}" -u "${!user}" -g "${!gateway}" -o "${oldMaster}"
  else
    log "[error] configuration for cluster ${failureClusterAlias} is not found!"
    exit 1
  fi

else

  log "[error] recovery is not supported for this failure ${failureType}!"
  exit 1

fi
