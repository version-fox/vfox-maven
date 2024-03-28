local util = require("util")

--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local m4 = util:parseVersion("maven-4/")
    local m3 = util:parseVersion("maven-3/")
    for _, v in ipairs(m3) do
        table.insert(m4, v)
    end
    table.sort(m4, function(a, b)
        return a.version > b.version
    end)
    return m4
end