local util = require("util")
local http = require("http")
--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local v = ctx.version
    local major = string.sub(v, 1, 1)
    if tonumber(major) ~= nil then
        if major == "3" or major == "4" then
            local checksums = {
                sha512 = util.CHECKSUM_URL:format(major, v, v, "sha512"),
                md5 = util.CHECKSUM_URL:format(major, v, v, "md5"),
                sha1 = util.CHECKSUM_URL:format(major, v, v, "sha1"),
            }
            for k, url in pairs(checksums) do
                local resp, err = http.get({
                    url = url
                })
                if err == nil and resp.status_code == 200 then
                    local result = {
                        version = v,
                        url = util.FILE_URL:format(major, v, v),
                    }
                    local removeSpace = string.match(resp.body,"(.-)%s")
                    result[k] = removeSpace or resp.body
                    return result
                end
            end
        else
            error("invalid version: " .. v)
        end
    else
        error("invalid version: " .. v)
    end
    return {}
end