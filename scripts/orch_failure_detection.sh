#!/bin/bash

set -e

# This argument is passed from orchestrator.
master=${1}
# Ping timeout, seconds 
timeout=10

is_icmp_pingable() {
  echo "[info] trying ICMP ping"
  if ping -w ${timeout} ${master}; then
    return 0
  else
  	return 1
  fi
}

is_tcp_pingable() {
  echo "[info] trying TCP ping"
  if nc -w ${timeout} -z ${master} 3306; then
    return 0
  else
  	return 1
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

echo "[info] TCP ping result: ${by_tcp}"
echo "[info] ICMP ping result: ${by_icmp}"

if [ "${by_tcp}" = 0 ] && [ "${by_icmp}" = 0 ]; then
  echo "[warn] Master is pingable (ICMP and TCP) so it is alive - false trigger?"
  exit 1 # Stop recovery process
else
  echo "[info] Master is not pingable (ICMP and TCP) so continue the recovery process..."
  exit 0
fi
