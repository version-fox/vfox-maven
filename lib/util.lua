local html = require("html")
local http = require("http")
local util = {}


util.MAVEN_URL = "https://dlcdn.apache.org/dist/maven/"
util.FILE_URL = "https://dlcdn.apache.org/dist/maven/maven-%s/%s/binaries/apache-maven-%s-bin.tar.gz"
util.CHECKSUM_URL = "https://dlcdn.apache.org/dist/maven/maven-%s/%s/binaries/apache-maven-%s-bin.tar.gz.%s"

function util:parseVersion(path)
    local resp, err = http.get({
        url = util.MAVEN_URL .. path
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("paring release info failed." .. err)
    end
    local result = {}
    html.parse(resp.body):find("a"):each(function(i, selection)
        local href = selection:attr("href")
        local sn = string.match(href, "^%d")
        local es = string.match(href, "/$")
        if sn and es then
            table.insert(result, {
                version = string.sub(href, 1, -2),
                note = "",
            })
        end
    end)
    return result
end
return util
