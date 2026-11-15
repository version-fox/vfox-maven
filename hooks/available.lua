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
local maven_version = require("maven_version")

--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local versions = {}
    for _, major in ipairs(util.MAJORS) do
        for _, release in ipairs(util:listVersions(major)) do
            table.insert(versions, release)
        end
    end
    -- The stable releases come first, then the pre-releases, each group newest first. vfox takes
    -- the first entry for `latest`, so `latest` is the newest stable release.
    table.sort(versions, function(a, b)
        local pre_a = maven_version.is_prerelease(a.version)
        local pre_b = maven_version.is_prerelease(b.version)
        if pre_a ~= pre_b then
            return not pre_a
        end
        return maven_version.compare(a.version, b.version) > 0
    end)
    return versions
end
