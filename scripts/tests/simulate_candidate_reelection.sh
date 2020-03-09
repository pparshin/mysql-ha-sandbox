#!/bin/bash

# create test cluster: M-S-S
make scale n=2
make load_schema
make discover

# create errant transactions on single slave
docker exec -it replica1 mysql -e "insert into sandbox.test values()"
# prefer node this errant transactions
make node_prefer fqdn=172.20.0.3