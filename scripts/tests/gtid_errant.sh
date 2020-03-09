#!/bin/bash

# create test cluster: M-S-S
make scale n=2
make load_schema
make discover

# create errant transactions
# without "set sql_log_bin=0;" replication would be broken after failover
docker exec -it replica1 mysql -e "set sql_log_bin=0; alter table sandbox.test add index ts(ts)"
docker exec -it replica2 mysql -e "set sql_log_bin=0; alter table sandbox.test add index ts(ts)"
docker exec -it orchestrator-sandbox_node1_1 mysql -e "set sql_log_bin=0; alter table sandbox.test add index ts(ts)"