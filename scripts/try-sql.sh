#!/bin/bash

export MYSQL_PWD=admin

function run() {
  echo 'Going to master'
  mysql -h 127.0.0.1 -P 3306 -uadmin --protocol tcp -e "SHOW VARIABLES LIKE 'SERVER_ID'"

  echo 'Going to slave x2 (round robin)'
  mysql -h 127.0.0.1 -P 3307 -uadmin --protocol tcp -e "SHOW VARIABLES LIKE 'SERVER_ID'"
  mysql -h 127.0.0.1 -P 3307 -uadmin --protocol tcp -e "SHOW VARIABLES LIKE 'SERVER_ID'"

  echo 'Write to master'
  mysql -h 127.0.0.1 -P 3306 -uadmin --protocol tcp -e "INSERT INTO sandbox.test VALUES()"

  mysql -h 127.0.0.1 -P 3307 -uadmin --protocol tcp -e "SELECT COUNT(*) FROM sandbox.test"

  return 0
}

cycles=${1:-1}

for ((i = 1; i <= cycles; i++)); do
  if [ ${i} -gt 1 ]; then
    sleep 1
  fi

  run
done
