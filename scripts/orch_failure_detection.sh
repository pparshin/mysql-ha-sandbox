#!/bin/bash

set -e

# Enable pretty logger.
function log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $(printf "%s" "$@")"
}

printf "\n# New Recovery\n"

user_commands=("force-master-failover" "force-master-takeover" "graceful-master-takeover")
if [[ " ${user_commands[@]} " =~ " ${ORC_COMMAND} " ]]; then
  log "[info] it is a manual failover (${ORC_COMMAND}) so skip the prefailover process"
  exit 0
fi

log "[info] ensure that master is not pingable by ICMP and TCP"

# This argument is passed from orchestrator.
master=${1}
# Ping timeout, seconds
timeout=10

is_icmp_pingable() {
  log "[info] trying ICMP ping..."
  if ping -w ${timeout} "${master}"; then
    return 1
  else
    return 0
  fi
}

is_tcp_pingable() {
  log "[info] trying TCP ping..."
  if nc -w ${timeout} -z "${master}" 3306; then
    return 1
  else
    return 0
  fi
}

is_icmp_pingable &
by_icmp_pid=$!

is_tcp_pingable &
by_tcp_pid=$!

by_tcp=0
wait ${by_tcp_pid} || by_tcp=$?
by_icmp=0
wait ${by_icmp_pid} || by_icmp=$?

log "[info] TCP ping result: ${by_tcp}"
log "[info] ICMP ping result: ${by_icmp}"

if [ "${by_tcp}" = 1 ] && [ "${by_icmp}" = 1 ]; then
  log "[warn] master is pingable (ICMP and TCP) so it is alive - false trigger?"
  exit 1 # Stop recovery process
else
  log "[info] master is not pingable (ICMP and TCP) so continue the recovery process..."
  exit 0
fi
