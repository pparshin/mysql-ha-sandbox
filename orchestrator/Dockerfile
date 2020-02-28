FROM orchestrator:latest

RUN apk --no-cache add openssh arping sed

RUN mkdir -p /root/.ssh && chmod 0700 /root/.ssh
COPY orchestrator/orchestrator_rsa /root/.ssh/orchestrator_rsa
COPY orchestrator/orchestrator_rsa.pub /root/.ssh/orchestrator_rsa.pub
COPY orchestrator/ssh_config /root/.ssh/config
RUN chmod -R 600 /root/.ssh/

RUN mkdir -p /usr/local/scripts
COPY scripts/orch_hook.sh /usr/local/scripts/orch_hook.sh
COPY scripts/orch_vip.sh /usr/local/scripts/orch_vip.sh
COPY scripts/orch_failure_detection.sh /usr/local/scripts/orch_failure_detection.sh
RUN chmod a+x /usr/local/scripts/orch_*.sh

ARG RAFT_BIND
COPY orchestrator/orchestrator.conf.json /etc/orchestrator.conf.json
RUN sed -i -e "s/#RAFT_BIND/${RAFT_BIND}/g" /etc/orchestrator.conf.json

RUN mkdir -p /var/lib/orchestrator
RUN chmod -R 755 /var/lib/orchestrator

CMD /entrypoint.sh