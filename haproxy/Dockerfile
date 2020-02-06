FROM haproxy:2.1.2-alpine

RUN apk add --no-cache net-tools socat

COPY scripts/wait-for.sh /root/wait-for.sh
RUN chmod a+x /root/wait-for.sh

COPY haproxy/haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg