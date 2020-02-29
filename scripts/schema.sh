#!/bin/bash

export MYSQL_PWD=admin

mysql -h 127.0.0.1 -u admin -P 3306 -e "
USE sandbox;
CREATE TABLE IF NOT EXISTS sandbox.test (
  id INT NOT NULL AUTO_INCREMENT,
  ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

USE meta;
CREATE TABLE IF NOT EXISTS cluster (
  anchor TINYINT NOT NULL,
  cluster_name VARCHAR(128) CHARSET ascii NOT NULL DEFAULT '',
  cluster_domain VARCHAR(128) CHARSET ascii NOT NULL DEFAULT '',
  PRIMARY KEY (anchor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO cluster (anchor, cluster_name, cluster_domain) 
VALUES (1, 'db_test', '172.20.0.200') ON DUPLICATE KEY UPDATE cluster_name=VALUES(cluster_name), cluster_domain=VALUES(cluster_domain);
"
