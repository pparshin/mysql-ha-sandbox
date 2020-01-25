#!/bin/bash

# This arguments are passed from orchestrator.
failureType=${1}
failureClusterAlias=${2}
oldMaster=${3}
newMaster=${4}
# Credentials to connect to databases.
dbUser="orchestrator"
export MYSQL_PWD="orchpass"

logfile="/var/log/orch_hook.log"

# Where "node1" is the name of the cluster, 
# “eth0:0” is the name of the interface where the VIP should be added, 
# “172.20.0.200” is the VIP on this cluster and 
# “root is the SSH user. 
# If we have multiple clusters, we have to add more arrays like this with the cluster details.
node1=( eth0:0 "172.20.0.200" root)

# https://github.com/github/orchestrator/blob/master/docs/failure-detection.md#deadmaster
if [[ ${failureType} == "DeadMaster" || ${failureType} == "UnreachableMaster" ]]; then

	array=${failureClusterAlias}
	interface=$array[0]
	IP=$array[1]
	user=$array[2]

	if [ ! -z ${!IP} ] ; then
		echo $(date)
		echo "Revocering from: ${failureType}"
		echo "New master is: ${newMaster}"
		echo "/usr/local/bin/orch_vip.sh -n ${newMaster} -i ${!interface} -I ${!IP} -u ${!user} -o ${oldMaster}" | tee ${logfile}
		/usr/local/bin/orch_vip.sh -n ${newMaster} -i ${!interface} -I ${!IP} -u ${!user} -o ${oldMaster}
	else
		echo "Cluster does not exist!" | tee ${logfile}
	fi

fi