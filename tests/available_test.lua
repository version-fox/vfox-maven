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

local test = require("vfox.test")

-- The directory listings of both sources, by URL. A URL with no listing is a 404.
local listings = {}
local plugin = test.load({
    http = function(request)
        local body = listings[request.url]
        if body == nil then
            return { status_code = 404, body = "" }
        end
        return { status_code = 200, body = body }
    end,
})

local DLCDN = "https://dlcdn.apache.org/maven/"
local ARCHIVE = "https://archive.apache.org/dist/maven/"

-- dlcdn.apache.org keeps the current releases. Its maven-2/ page names no release.
listings[DLCDN .. "maven-4/"] = [[
<html><body>
<a href="../">../</a>
<a href="4.0.0-rc-7/">4.0.0-rc-7/</a>
</body></html>
]]
listings[DLCDN .. "maven-3/"] = [[
<html><body>
<a href="../">../</a>
<a href="3.9.16/">3.9.16/</a>
<a href="3.10.0/">3.10.0/</a>
<a href="3.10.1/">3.10.1/</a>
</body></html>
]]
listings[DLCDN .. "maven-2/"] = [[
<html><body>
<a href="../">../</a>
<a href="http://maven.apache.org/maven-2.x-eol.html">Maven 2 end of life</a>
</body></html>
]]

-- archive.apache.org keeps every release, the old ones too. Some are listed twice.
listings[ARCHIVE .. "maven-4/"] = [[
<html><body>
<a href="../">../</a>
<a href="4.0.0-alpha-10/">4.0.0-alpha-10/</a>
<a href="4.0.0-alpha-2/">4.0.0-alpha-2/</a>
<a href="4.0.0-rc-7/">4.0.0-rc-7/</a>
</body></html>
]]
listings[ARCHIVE .. "maven-3/"] = [[
<html><body>
<a href="../">../</a>
<a href="3.0.5/">3.0.5/</a>
<a href="3.5.0-beta-1/">3.5.0-beta-1/</a>
<a href="3.9.16/">3.9.16/</a>
<a href="3.10.0/">3.10.0/</a>
<a href="3.10.1/">3.10.1/</a>
</body></html>
]]
listings[ARCHIVE .. "maven-2/"] = [[
<html><body>
<a href="../">../</a>
<a href="2.0.11/">2.0.11/</a>
<a href="2.2.1/">2.2.1/</a>
</body></html>
]]

-- Every release of both sources, once each, newest first: 4.0.0-rc-7 is after the
-- alpha releases, 4.0.0-alpha-10 after alpha-2, 3.10.1 after 3.10.0, 3.9.16 after
-- 3.5.0-beta-1, and 2.2.1 after 2.0.11.
local versions = plugin:Available({})
local got = {}
for i, v in ipairs(versions) do
    got[i] = v.version
end
local want = "4.0.0-rc-7,4.0.0-alpha-10,4.0.0-alpha-2,3.10.1,3.10.0,3.9.16,3.5.0-beta-1,3.0.5,2.2.1,2.0.11"
assert(table.concat(got, ",") == want, table.concat(got, ","))

print("PASS: Available lists the releases of both sources, newest first, each once")
