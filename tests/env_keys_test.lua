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

local keys = plugin:EnvKeys({ path = "/sdks/maven-3.10.1" })
assert(#keys == 1, "EnvKeys must set PATH and nothing else")
assert(keys[1].key == "PATH", keys[1].key)
assert(keys[1].value == "/sdks/maven-3.10.1/bin", keys[1].value)

print("PASS: EnvKeys puts the bin directory of the install on PATH")
