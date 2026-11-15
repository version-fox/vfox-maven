-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local util = require("util")

--- @class PreInstallContext
--- @field version string User-input version

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx PreInstallContext
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local v = ctx.version
    local major = util:majorOf(v)
    if major == nil then
        error("invalid version: " .. v)
    end
    local source = util:sourceOf(major, v)
    local url = util:archiveURL(source, major, v)
    for _, algorithm in ipairs(util.ALGORITHMS) do
        local digest = util:fetchDigest(url .. "." .. algorithm.name, algorithm.length)
        if digest ~= nil then
            return {
                version = v,
                url = url,
                [algorithm.name] = digest,
            }
        end
    end
    error("Maven " .. v .. " has no checksum file at " .. source)
end
