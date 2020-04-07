#!/bin/bash

# create test cluster: M-19S
make scale n=15
make load_schema
make discover

# change ROW based replication to MIXED for some replicas
for i in {10..12}; do
  docker exec -it replica${i} mysql -e "STOP SLAVE; SET @@GLOBAL.BINLOG_FORMAT=MIXED; START SLAVE;"
done

# add an intermediate master
docker exec -it replica6 mysql -e "STOP SLAVE; CHANGE MASTER TO MASTER_HOST='replica5', MASTER_PORT=3306, MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_AUTO_POSITION=1; START SLAVE;"
