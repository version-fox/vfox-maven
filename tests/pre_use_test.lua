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
local plugin = test.load()

local cases = 0

-- Checks the version that PreUse selects for spec, when the releases in installed are installed.
local function selects(spec, installed, want)
    local sdks = {}
    for _, version in ipairs(installed) do
        sdks[version] = { version = version, path = "/sdks/maven-" .. version }
    end
    local got = plugin:PreUse({ version = spec, installedSdks = sdks }).version
    assert(got == want, ("PreUse(%q) = %q, want %q"):format(spec, got, want))
    cases = cases + 1
end

-- The release as typed, when it is installed.
selects("3.10.1", { "3.10.1", "3.0.5" }, "3.10.1")
selects("4.0.0-alpha-2", { "4.0.0-alpha-2", "4.0.0-alpha-13" }, "4.0.0-alpha-2")

-- A major or minor version selects the newest installed release under it, in Maven's order.
-- vfox compares only the numbers, which would take 4.0.0-alpha-2 over 4.0.0-alpha-13.
selects("3", { "3.0.5", "3.9.11", "3.10.1" }, "3.10.1")
selects("4", { "4.0.0-alpha-2", "4.0.0-alpha-13" }, "4.0.0-alpha-13")
selects("4.0", { "4.0.0-alpha-13", "4.0.0-alpha-2" }, "4.0.0-alpha-13")
-- A release is after the pre-releases of the same numbers, whatever their names.
selects("4", { "4.0.0-rc-7", "4.0.0-alpha-13", "4.0.0-beta-5" }, "4.0.0-rc-7")
selects("3", { "3.0-beta-3", "3.0" }, "3.0")

-- A spec names whole parts: 3.1 is not 3.10.1, and 3 is not 30.0.0.
selects("3.1", { "3.10.1" }, "3.1")
selects("3", { "30.0.0" }, "3")
selects("3.0", { "3.0.5" }, "3.0.5")
-- Maven 1 has one release, 1.1, and its major version finds it.
selects("1", { "1.1" }, "1.1")

-- Nothing installed under the spec: the spec is returned, so vfox reports it as not installed.
selects("3", {}, "3")
selects("3.9", { "3.10.1" }, "3.9")

-- Without the installed list the spec is returned as it is.
assert(plugin:PreUse({ version = "3" }).version == "3", "PreUse without installedSdks must return the spec")
-- Without a spec there is nothing to return.
assert(plugin:PreUse({ version = "" }) == nil, "PreUse without a spec must return nothing")

print(("PASS: PreUse selects the installed release that a spec names: %d cases"):format(cases))
