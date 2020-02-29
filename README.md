# [MySQL Orchestrator](https://github.com/github/orchestrator)/HAProxy/VIP sandbox

This sandbox is designed to safely experiment with High Availability solution based on MySQL Orchestrator, HAProxy 
and virtual IP (VIP).

The sandbox uses Docker and Docker Compose to up and down MySQL cluster and all its dependencies.

The sandbox has next configuration:

  1. MySQL cluster (1 master, N replicas). MySQL version - 5.7.
  2. MySQL orchestrator cluster using raft consensus (3 nodes). 
  3. HAProxy instance which used to spread SQL read queries across replicas.
  4. Simple Bash script to emulate read/write queries.

To down and up network interfaces SSH key is added to every MySQL nodes.  

## MySQL Orchestrator

```bash
# Clone Git repository
cd <work-dir>
git clone https://github.com/github/orchestrator.git orchestrator/source

# Build Docker image
cd orchestrator/source
docker build -t orchestrator:latest .
```

## VIP (virtual IP)

- 172.20.0.200 - master
- 172.20.0.2xx - replica xx (1..20)

## HAProxy

Administrative section is available on [http://localhost:8080](http://localhost:8080)

## How to discover the cluster topology by orchestrator

Use web [UI](http://localhost:80) or a command line:

```bash
make discover
```

How to print the current cluster topology:

```bash
make orchestrator-client c="-c topology -i db_test cli"
```

## Configure and run the sandbox

Build and up all containers:

```bash
make clean
make up
# Where n is a total number of replicas, max 20.
make scale n=10
```

Load SQL schema and discover the topology:

```bash
make load_schema
make discover
```

Wait a few seconds and you can play with cluster as you would like, e.g.:

```bash
# Emulate read/write queries in the backgroung or separate terminal 
make try_sql n=200
# Block the master using iptables (mimic a network partitioning)
make node_drop n=orchestrator-sandbox_node1_1
# Or completely stop the master
docker-compose stop node1
```

You should expect that orchestrator detects master downtime and start the failover process. 
A new master will be elected and topology will be rebuilt after 20-30 seconds.

## FAQ

### How to get back an old master to a new cluster after failover?

Run next commands on old master:

```sql
SET @@GLOBAL.READ_ONLY=1;
SET @@GLOBAL.SLAVE_NET_TIMEOUT=4; 
CHANGE MASTER TO MASTER_HOST='172.20.0.200', MASTER_PORT=3306, MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_AUTO_POSITION=1;
CHANGE MASTER TO MASTER_CONNECT_RETRY=1, MASTER_RETRY_COUNT=86400, MASTER_HEARTBEAT_PERIOD=2;
START SLAVE;
```

Update the orchestrator:

```bash
# -i - old master, -d - new master
ORCHESTRATOR_API="http://127.0.0.1:80/api" scripts/orchestrator-client -c relocate -i 172.20.0.11 -d 172.20.0.12
```

### Which options might affect on time to detect a problem and recover a master?

Read (really read) the orchestrator [documentation](https://github.com/github/orchestrator/blob/master/docs/configuration-failure-detection.md#mysql-configuration).

Read MySQL [documentation](https://dev.mysql.com/doc/refman/5.7/en/change-master-to.html) carefully and pay attention to:

> Note that a change to the value or default setting of slave_net_timeout does not automatically change the heartbeat interval, 
> whether that has been set explicitly or is using a previously calculated default. ... 
> If slave_net_timeout is changed, you must also issue CHANGE MASTER TO to adjust the heartbeat interval 
> to an appropriate value so that the heartbeat signal occurs before the connection timeout.

How to get current value of `MASTER_HEARTBEAT_PERIOD`:

```mysql
SELECT HEARTBEAT_INTERVAL FROM performance_schema.replication_connection_configuration;
```

How to update `slave_net_timeout`:

```mysql
STOP SLAVE; 
SET @@GLOBAL.SLAVE_NET_TIMEOUT=4; 
START SLAVE;
```

How to check the current connection status between replica and master:

```mysql
SELECT * FROM performance_schema.replication_connection_status\G;"
```

Play with next orchestrator options:

 - `DelayMasterPromotionIfSQLThreadNotUpToDate`,
 - `InstancePollSeconds`,
 - `RecoveryPollSeconds`. Basically, it is a hardcoded [constant]((https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/config/config.go#L45)) which defines how often to run topology analyze.

Each node of cluster is probed once every `InstancePollSeconds` seconds. 
If a problem is detected, orchestrator forcefully [updates](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/logic/topology_recovery.go#L1409) 
cluster topology and decides to execute recovery or not.

### What the meaning of cluster_domain from meta table?

Has no direct influence on orchestrator and how it performs the recovery. 

It might be useful in hooks to implement your own logic: 

 - as a placeholder `{failureClusterDomain}`,
 - as a environment variable `ORC_FAILURE_CLUSTER_DOMAIN` ([topology_recovery.go#L314](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/logic/topology_recovery.go#L314)).
