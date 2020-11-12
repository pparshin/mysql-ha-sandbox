ARG VERSION=2.6.1
FROM tarantool/tarantool:${VERSION}

COPY init.lua /etc/tarantool/instances.enabled/init.lua
CMD ["tarantool", "/etc/tarantool/instances.enabled/init.lua"]