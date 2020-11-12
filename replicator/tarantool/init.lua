box.cfg { listen = 3301 }

box.once("init", function()
    box.schema.user.create('repl', { password = 'repl', if_not_exists = true })
    box.schema.user.grant('repl', 'read,write,create,execute', 'universe')

    local s = box.schema.space.create("sandbox", {
        if_not_exists = true,
    })

    s:format({
        { name = 'id', type = 'unsigned' },
        { name = 'ts', type = 'string' },
    })

    s:create_index('primary', {
        type = 'hash',
        if_not_exists = true,
        parts = { 'id' },
    })
end)