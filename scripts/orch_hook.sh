#!/bin/bash

set -e

# This arguments are passed from orchestrator.
failureType=${1}
failureClusterAlias=${2}
oldMaster=${3}
newMaster=${4}

# SSH options used to connect to servers when moving VIP.
sshOptions="-o ConnectTimeout=5"

# Credentials to connect to databases.
dbUser="orchestrator"
export MYSQL_PWD="orchpass"

logfile="/tmp/orch_hook.log"

# Where "db_test" is the name of the cluster, 
# "eth0:0" is the name of the interface where the VIP should be added, 
# "172.20.0.200" is the VIP on this cluster,
# "172.20.0.1" is the gateway used to update by arping,
# "root" is the SSH user.
#
# If we have multiple clusters, we have to add more arrays like this with the cluster details.
db_test=( eth0:0 "172.20.0.200" "172.20.0.1" root)

# Failure types which we should recover from.
# https://github.com/github/orchestrator/blob/master/docs/failure-detection.md
failureTypes=( "DeadMaster" "DeadMasterAndSomeSlaves" )

if [[ " ${failureTypes[@]} " =~ " ${failureType} " ]]; then

	array=${failureClusterAlias}
	interface=$array[0]
	IP=$array[1]
	gateway=$array[2]
	user=$array[3]

	if [ ! -z ${!IP} ] ; then
		echo $(date)
		echo "Revocering from: ${failureType}"
		echo "New master is: ${newMaster}"
		echo "/usr/local/bin/orch_vip.sh -n ${newMaster} -i ${!interface} -s \"${sshOptions}\" -I ${!IP} -u ${!user} -g ${gateway} -o ${oldMaster}" | tee ${logfile}
		/usr/local/bin/orch_vip.sh -n ${newMaster} -i ${!interface} -s "${sshOptions}" -I ${!IP} -u ${!user} -g ${gateway} -o ${oldMaster} | tee ${logfile}
	else
		echo "Cluster does not exist!" | tee ${logfile}
	fi

else

	echo "Recovery is not supported for this failure ${failureType}!"
	exit 1

fi