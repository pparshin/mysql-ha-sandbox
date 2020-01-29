FROM orchestrator:latest

RUN apk --no-cache add openssh arping

RUN mkdir -p /root/.ssh && chmod 0700 /root/.ssh
COPY orchestrator/orchestrator_rsa /root/.ssh/id_rsa
COPY orchestrator/orchestrator_rsa.pub /root/.ssh/id_rsa.pub
COPY orchestrator/ssh_config /root/.ssh/config
RUN chmod -R 600 /root/.ssh/

COPY scripts/orch_hook.sh /usr/local/bin/orch_hook.sh
COPY scripts/orch_vip.sh /usr/local/bin/orch_vip.sh
COPY scripts/orch_failure_detection.sh /usr/local/bin/orch_failure_detection.sh
RUN chmod a+x /usr/local/bin/orch_*.sh

CMD /entrypoint.sh