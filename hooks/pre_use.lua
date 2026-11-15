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

local maven_version = require("maven_version")

--- When user invoke `use` command, this function will be called to get the
--- valid version information.
---
--- Without this hook vfox matches a spec itself, and it compares only the numbers of
--- versions: 4.0.0-alpha-2 and 4.0.0-alpha-13 are the same to it, so it may take the
--- older one. Here the release named as typed is used when it is installed. Otherwise
--- the newest installed release under the spec is used, in Maven's order. A spec that
--- names no installed release is returned as it is, for vfox to report as not installed.
--- @param ctx table Context: version, and installedSdks keyed by version
--- @return table|nil The version to use, or nil when there is no spec
function PLUGIN:PreUse(ctx)
    local spec = ctx.version
    if spec == nil or spec == "" then
        return nil
    end
    local installed = ctx.installedSdks or {}
    if installed[spec] ~= nil then
        return { version = spec }
    end
    local prefix = spec .. "."
    local matches = {}
    for version in pairs(installed) do
        if version:sub(1, #prefix) == prefix then
            table.insert(matches, version)
        end
    end
    if #matches == 0 then
        return { version = spec }
    end
    -- The order is total: two releases that compare the same are ordered by their names.
    table.sort(matches, function(a, b)
        local order = maven_version.compare(a, b)
        if order ~= 0 then
            return order > 0
        end
        return a > b
    end)
    return { version = matches[1] }
end
