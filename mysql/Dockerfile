FROM ubuntu:xenial

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
  apt-utils \
  curl \
  tzdata \
  netcat \
  net-tools \
  iputils-ping \
  openssh-server \
  iptables \
  screen

RUN mkdir /var/run/sshd
RUN mkdir -p /root/.ssh && chmod 0700 /root/.ssh
COPY orchestrator/orchestrator_rsa.pub /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

RUN apt-get install -y mysql-server-5.7 \
                       mysql-client-core-5.7 \
                       mysql-utilities

RUN apt-get install -y arping

COPY mysql/my.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
RUN chown root:root /etc/mysql/mysql.conf.d/mysqld.cnf

COPY mysql/entrypoint.sh /root/entrypoint.sh
RUN chmod a+x /root/entrypoint.sh

COPY scripts/wait-for.sh /root/wait-for.sh
RUN chmod a+x /root/wait-for.sh

RUN rm -rf /var/lib/apt/lists/*

EXPOSE 3306/tcp

CMD ["/root/entrypoint.sh"]