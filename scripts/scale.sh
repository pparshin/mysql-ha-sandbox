#!/bin/bash

set -e

nodes=${1}
gateway=172.20.0.1

for (( i = 1; i <= ${nodes}; i++ )); do
	name="replica${i}"
	vip=""
	if [[ i -lt 10 ]]; then
		vip="172.20.0.20${i}"
	else
		vip="172.20.0.2${i}"
	fi
	docker stop ${name} || true
	docker rm ${name} || true
	docker run --name ${name} -d --rm --network orchestrator-sandbox_orchsandbox --cap-add NET_ADMIN --cap-add NET_RAW -e GATEWAY=${gateway} -e VIP=${vip} --privileged orch_sandbox_node
done

for (( i = 1; i <= ${nodes}; i++ )); do
	name="replica${i}"
	docker exec -it ${name} /bin/bash -c '/root/wait-for.sh 127.0.0.1:3306'
	docker exec -it ${name} mysql -e "STOP SLAVE; SET @@GLOBAL.SLAVE_NET_TIMEOUT=4; START SLAVE;"

	# Enable server.
	cmd="set server read_nodes/reader${i} state ready"
	docker-compose exec haproxy /bin/sh -c "echo ${cmd} | socat stdio /var/run/hapee-lb.sock"
done