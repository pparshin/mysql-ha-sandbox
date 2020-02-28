#!/bin/bash

#set -x

function usage() {
  cat <<EOF
 usage: $0 [-h] [-o old master ] [-s ssh options] [-n new master] [-i interface] [-I] [-g gateway] [-u SSH user]
 
 OPTIONS:
    -h        Show this message
    -o string Old master hostname or IP address 
    -s string SSH options
    -n string New master hostname or IP address
    -i string Interface, e.g. eth0:0
    -I string Virtual IP
    -g string Subnet gateway 
    -u string SSH user
EOF

}

while getopts ho:s:n:i:I:g:u: flag; do
  case $flag in
  o)
    oldMaster="${OPTARG}"
    ;;
  s)
    sshOptions="${OPTARG}"
    ;;
  n)
    newMaster="${OPTARG}"
    ;;
  i)
    interface="${OPTARG}"
    ;;
  I)
    vip="${OPTARG}"
    ;;
  u)
    sshUser="${OPTARG}"
    ;;
  g)
    gateway="${OPTARG}"
    ;;
  h)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

# Enable pretty logger.
function log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $(printf "%s" "$@")"
}

# command for adding our VIP
cmd_vip_add="ifconfig ${interface} ${vip} up"
# command for deleting our VIP
cmd_vip_del="ifconfig ${interface} down"
# command for discovering if our VIP is enabled
cmd_vip_chk="ifconfig | grep 'inet addr' | grep ${vip}"
# command for sending gratuitous ARP to announce IP move
cmd_arp_fix="\$(which arping) -c 3 -I ${interface} -S ${vip} ${gateway}"
cmd_arp_force_fix="\$(which arping) -I ${interface} -S ${vip} ${gateway}" # infinite arping

vip_stop() {
  rc=0

  # ensure the VIP is removed
  log "[info] attempt to remove VIP. SSH command will be executed..."
  local OUT
  OUT=$(
    ssh ${sshOptions} -tt "${sshUser}"@"${oldMaster}" \
      "[ -n \"\$(${cmd_vip_chk})\" ] && ${cmd_vip_del} && ${cmd_arp_fix} || [ -z \"\$(${cmd_vip_chk})\" ]" 2>&1
  )

  rc=$?
  log "[info] SSH command exit code: ${rc}, output:"
  echo "${OUT}"

  return ${rc}
}

vip_start() {
  rc=0

  # ensure the VIP is added
  # this command should exit with failure if we are unable to add the VIP
  # if the VIP already exists always exit 0 (whether or not we added it)
  log "[info] attempt to add VIP. SSH command will be executed..."
  local OUT
  OUT=$(
    ssh ${sshOptions} -tt "${sshUser}"@"${newMaster}" \
      "[ -z \"\$(${cmd_vip_chk})\" ] && ${cmd_vip_add} && ${cmd_arp_fix} || [ -n \"\$(${cmd_vip_chk})\" ]" 2>&1
  )

  rc=$?
  log "[info] SSH command exit code: ${rc}, output:"
  echo "${OUT}"

  return ${rc}
}

# If we do not remove VIP from old master (e.g. some SSH problems),
# run infinite arping.
force_arping() {
  log "[info] attempt to exec infinite arping. SSH command will be executed..."
  local OUT
  OUT=$(
    ssh ${sshOptions} -f "${sshUser}"@"${newMaster}" "screen -dmS orch_force_arping_STOP_ME bash -c '${cmd_arp_force_fix}'" 2>&1
  )

  rc=$?
  log "[info] SSH command exit code: ${rc}, output:"
  echo "${OUT}"
}

log "[info] master is dead, trying to move VIP ${vip} from old master (${oldMaster}) to a new one (${newMaster})"

vipRemovedFromOldMaster=false

log '[info] make sure the VIP is not available attempting to down the network interface on old master'
if vip_stop; then
  vipRemovedFromOldMaster=true
  log "[info] VIP ${vip} is removed from old master ${oldMaster}"
else
  # We do not treat it as a fatal error.
  log "[info] failed to remove VIP ${vip} from old master ${oldMaster}"
fi

log '[info] moving VIP to new master'
if vip_start; then
  log "[info] VIP ${vip} is moved to new master ${newMaster}"
  if [ "${vipRemovedFromOldMaster}" = false ]; then
    log "[warn] arping is going to run in the background process!"
    force_arping
  fi
else
  log "[error] failed to add VIP ${vip} on new master ${newMaster}!"
  exit 1
fi
