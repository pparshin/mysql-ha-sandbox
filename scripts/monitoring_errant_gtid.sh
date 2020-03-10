#!/bin/bash

# executable path to orchestrator-client
client=./scripts/orchestrator-client
if [ ! -x "${client}" ]; then
  echo "[fatal] required orchestrator-client is not executable or found: \"${client}\"!"
  exit 1
fi

# credentials to auth to orchestrator
credentials="dba_team:time_for_dinner"

export ORCHESTRATOR_API="http://127.0.0.1:80/api"

command=${1}
# if 1 than instance will be checked only if this script is executed on the orchestrator leader machine.
raft_exec_only_on_leader=1
raft_node_hostname=$(hostname)

api_response=

clusters=
cluster_replicas=

json='{"data": []}'

function client_call() {
  command=${1}
  rc=0

  api_response=$(timeout 20 "${client}" -b "${credentials}" -c ${command} 2>&1)

  rc=$?
  if [[ ${rc} -eq 0 ]]; then
    return
  else
    echo "[fatal] orchestrator client returned non-zero exit code: ${rc}, output:"
    echo "${api_response}"
    exit 1
  fi
}

function fetch_clusters() {
  client_call "clusters-alias"
  mapfile -t clusters < <(echo "${api_response}" | awk -F, '{print $2}')
}

function fetch_cluster_replicas() {
  cluster_alias=${1}

  client_call "which-cluster-master -a ${cluster_alias}"
  cluster_master="${api_response}"

  client_call "which-replicas -i ${cluster_master}"
  mapfile -t cluster_replicas < <(echo "${api_response}" | awk -F: '{print $1}')
}

function discover() {
  fetch_clusters
  for cluster in "${clusters[@]}"; do
    fetch_cluster_replicas "${cluster}"

    for replica in "${cluster_replicas[@]}"; do
      replica_data=$(
        jq -n \
          --arg ca "${cluster}" \
          --arg fqdn "${replica}" \
          '{"{#ORCH_CLUSTER_ALIAS}": $ca, "{#ORCH_REPLICA_FQDN}": $fqdn}'
      )
      json=$(jq ".data += [${replica_data}]" <<<"${json}")
    done
  done
}

function can_check_instance() {
  if [ ${raft_exec_only_on_leader} == 0 ]; then
    return 0
  fi

  client_call "raft-leader-hostname"
  raft_leader="${api_response}"

  if [ "${raft_leader}" == "${raft_node_hostname}" ]; then
    return 0
  fi

  return 1
}

function check_instance() {
  replica=${1}

  replica_errant_gtid=""
  if can_check_instance; then
    # Do request only on raft leader
    client_call "which-gtid-errant -i ${replica}"
    replica_errant_gtid="${api_response}"
  fi

  json=$(
    jq -n \
      --arg fqdn "${replica}" \
      --arg errant "${replica_errant_gtid}" \
      '{"fqdn": $fqdn, "errant_gtid": $errant}'
  )
}

if [ "${command}" == "discover" ]; then
  discover
elif [[ -n "${command}" ]]; then
  check_instance "${command}"
else
  echo "[fatal] no command given. Discover clusters or check an instance whether it has errant GTID"
  exit 1
fi

echo "${json}"
