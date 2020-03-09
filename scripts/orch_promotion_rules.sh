#!/bin/bash

# executable path to orchestrator-client
client=./scripts/orchestrator-client
if [ ! -x "${client}" ]; then
  echo "[fatal] required orchestrator-client is not executable or found: \"${client}\"!"
  exit 1
fi

# credentials to auth to orchestrator
credentials="dba_team:time_for_dinner"

# list of rules to apply.
# possible promotion values: prefer, neutral, prefer_not, must_not
# key is a FQDN of cluster node.
declare -A rules
rules=(
  ["172.20.0.3"]="prefer"
  ["172.20.0.4"]="must_not"
)

export ORCHESTRATOR_API="http://127.0.0.1:80/api"

for fqdn in "${!rules[@]}"; do
  promotion=rules[${fqdn}]

  echo "[info] will apply promotion rule '${!promotion}' to '${fqdn}'"
  "${client}" -b "${credentials}" -c register-candidate -i "${fqdn}" --promotion-rule "${!promotion}"
  echo "-------------------"
done
