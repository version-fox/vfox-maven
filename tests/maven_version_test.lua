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
test.load()
local maven_version = require("maven_version")

local cases = 0

-- Checks that compare(a, b) has the given sign: -1, 0 or 1.
local function orders(a, b, sign)
    local got = maven_version.compare(a, b)
    assert(got == sign, ("compare(%q, %q): expected %d, got %d"):format(a, b, sign, got))
    cases = cases + 1
end

-- Numbers compare as numbers: 3.10.1 is after 3.9.16, which the text order gets wrong.
orders("3.10.1", "3.9.16", 1)
orders("3.9.16", "3.10.1", -1)
orders("3.10.0", "3.9.99", 1)
orders("4.0.0", "3.10.1", 1)
orders("3.9.9", "3.9.9", 0)
-- A missing number is zero, so 4.0 is the same release as 4.0.0.
orders("4.0", "4.0.0", 0)

-- A release is after its pre-releases.
orders("4.0.0", "4.0.0-rc-7", 1)
orders("4.0.0-rc-7", "4.0.0", -1)
orders("4.0.0-rc-7", "4.0.0-rc-7", 0)
-- Words compare as words and numbers as numbers: beta is before rc, and rc-10 after rc-3.
orders("4.0.0-beta-5", "4.0.0-rc-3", -1)
orders("4.0.0-rc-3", "4.0.0-rc-10", -1)
orders("4.0.0-rc-10", "4.0.0-rc-3", 1)

-- Releases in the archive: 4.0.0-alpha-10 is after alpha-2, 3.10.0-rc-1 is before
-- 3.10.0 and after 3.9.16, and old releases such as 2.2.1 and 3.0.5 keep their order.
orders("4.0.0-alpha-10", "4.0.0-alpha-2", 1)
orders("3.10.0-rc-1", "3.10.0", -1)
orders("3.10.0-rc-1", "3.9.16", 1)
orders("3.5.0-alpha-1", "3.5.0-beta-1", -1)
orders("2.2.1", "2.0.11", 1)
orders("3.0.5", "3.5.0-beta-1", -1)
orders("1.1", "2.0.11", -1)

print("PASS: " .. cases .. " Maven version cases")
