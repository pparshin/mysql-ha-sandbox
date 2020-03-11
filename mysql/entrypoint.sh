#!/bin/bash

set -e

MYSQL_REPORT_HOST=$(/sbin/ip route | awk '/kernel/ { print $9 }')
MYSQL_SERVER_ID="${MYSQL_REPORT_HOST//./}"

sed -i -e "s/#REPORT_HOST/${MYSQL_REPORT_HOST}/g" /etc/mysql/mysql.conf.d/mysqld.cnf
sed -i -e "s/#SERVER_ID/${MYSQL_SERVER_ID}/g" /etc/mysql/mysql.conf.d/mysqld.cnf

DATADIR="/var/lib/mysql"
SOCKETDIR="/var/run/mysqld/"
SOCKET="/var/run/mysqld/mysqld.sock"
CMD=(mysql --protocol=socket -uroot --socket="$SOCKET")

rm -rf "$DATADIR"
mkdir -p "$DATADIR"
mkdir -p "$SOCKETDIR"
chown -R mysql:mysql "$DATADIR"
chown -R mysql:root "$SOCKETDIR"

echo '[Entrypoint] Initializing database.'
mysqld --initialize-insecure \
       --datadir="$DATADIR"
echo '[Entrypoint] Database initialized.'

mysqld --daemonize --skip-networking --socket="$SOCKET"

for i in {30..0}; do
  if mysqladmin --socket="$SOCKET" ping &>/dev/null; then
    break
  fi
  echo '[Entrypoint] Waiting for server...'
  sleep 1
done
if [ "$i" = 0 ]; then
  echo >&2 '[Entrypoint] Timeout during MySQL init.'
  exit 1
fi

echo "[Entrypoint] Populate TimeZone..."
# With "( .. ) 2> /dev/null" suppress any std[out/err].
(mysql_tzinfo_to_sql /usr/share/zoneinfo | "${CMD[@]}" --force) 2>/dev/null

echo "[Entrypoint] Create users and config replication."

if [ ! -z "${IS_MASTER}" ]; then
  "${CMD[@]}" <<-EOSQL
  SET @@SESSION.SQL_LOG_BIN=0;
  
  CREATE DATABASE IF NOT EXISTS sandbox;
  CREATE DATABASE IF NOT EXISTS meta;

  CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl';
  GRANT REPLICATION SLAVE ON *.* TO 'repl'@'172.20.0.%' IDENTIFIED BY 'repl';
  SHOW MASTER STATUS;
  
  CREATE USER 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'admin';
  GRANT ALL ON *.* TO 'admin'@'%' IDENTIFIED BY 'admin' WITH GRANT OPTION;

  GRANT ALL PRIVILEGES ON orchestrator.* TO 'orchestrator'@'%' IDENTIFIED BY 'orchpass';
  GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orchestrator'@'%';
  GRANT ALL PRIVILEGES ON orchestrator.* TO 'orchestrator'@'localhost' IDENTIFIED BY 'orchpass';
  GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orchestrator'@'localhost';
  GRANT ALL PRIVILEGES ON meta.* TO 'orchestrator'@'%';

  FLUSH PRIVILEGES;

  SET @@SESSION.SQL_LOG_BIN=1;
EOSQL
else
  "${CMD[@]}" <<-EOSQL
  SET @@SESSION.SQL_LOG_BIN=0;
  
  CREATE DATABASE IF NOT EXISTS sandbox;
  CREATE DATABASE IF NOT EXISTS meta;

  CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl';
  GRANT REPLICATION SLAVE ON *.* TO 'repl'@'172.20.0.%' IDENTIFIED BY 'repl';

  CREATE USER 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'admin';
  GRANT ALL ON *.* TO 'admin'@'%' IDENTIFIED BY 'admin' WITH GRANT OPTION;

  GRANT ALL PRIVILEGES ON orchestrator.* TO 'orchestrator'@'%' IDENTIFIED BY 'orchpass';
  GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orchestrator'@'%';
  GRANT ALL PRIVILEGES ON orchestrator.* TO 'orchestrator'@'localhost' IDENTIFIED BY 'orchpass';
  GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orchestrator'@'localhost';
  GRANT ALL PRIVILEGES ON meta.* TO 'orchestrator'@'%';

  FLUSH PRIVILEGES;

  SET @@SESSION.SQL_LOG_BIN=1;

  CHANGE MASTER TO MASTER_HOST='172.20.0.200', MASTER_PORT=3306, MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_AUTO_POSITION=1;
  CHANGE MASTER TO MASTER_CONNECT_RETRY=1, MASTER_RETRY_COUNT=86400, MASTER_HEARTBEAT_PERIOD=2;
  START SLAVE;
  SHOW SLAVE STATUS\G;
EOSQL
fi

mysqladmin shutdown -uroot --socket="$SOCKET"

echo '[Entrypoint] MySQL init process done. Ready for start up.'

if [[ -n "${VIP}" ]]; then
  echo "[Entrypoint] Assign VIP: ${VIP}"
  ip address add "${VIP}"/32 dev eth0
  arping -c 3 -S "${VIP}" -I eth0 "${GATEWAY}"
fi

echo '[Entrypoint] Starting sshd up...'
/usr/sbin/sshd

echo '[Entrypoint] Starting mysqld up...'
mysqld
