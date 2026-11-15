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

-- The Maven homes that `vfox link --detect maven` finds on macOS: Homebrew keeps Maven in the
-- libexec of its keg, on Apple silicon and on Intel.
local test = require("vfox.test")
local plugin = test.load({
    os = "darwin",
    arch = "arm64",
    env = { HOME = "/Users/test" },
})
local detect = require("detect_maven")

local files = {}
local dirs = {}

local function norm(path)
    return ((path or ""):gsub("\\", "/"))
end

io.open = function(path, mode)
    if (mode or "r") ~= "r" or not files[norm(path)] then
        return nil
    end
    return {
        read = function()
            return ""
        end,
        close = function()
            return true
        end,
    }
end

-- The handle has read and close only, as vfox's io.popen has on Windows, so the code cannot
-- depend on lines.
io.popen = function(cmd)
    local dir = cmd:match("'([^']+)'") or cmd:match('"([^"]+)"')
    local children = (dir and dirs[norm(dir)]) or {}
    local index = 0
    return {
        read = function(_, format)
            if format == "*a" then
                return ""
            end
            index = index + 1
            return children[index]
        end,
        close = function()
            return true
        end,
    }
end

-- A Maven home at home, whose lib directory holds the file names given.
local function maven(home, lib)
    files[norm(home .. "/bin/mvn")] = true
    dirs[norm(home .. "/lib")] = lib or {}
end

local function entries(dir, names)
    dirs[norm(dir)] = names
end

-- Apple silicon: the keg of Homebrew's maven, whose home is its libexec.
entries("/opt/homebrew/opt", { "maven", "openjdk" })
maven("/opt/homebrew/opt/maven/libexec", { "maven-core-3.9.11.jar" })
entries("/opt/homebrew/opt/openjdk", {})
-- Intel: Homebrew under /usr/local.
entries("/usr/local/opt", { "maven" })
maven("/usr/local/opt/maven/libexec", { "maven-core-3.8.8.jar" })
-- SDKMAN.
entries("/Users/test/.sdkman/candidates/maven", { "4.0.0-rc-7" })
maven("/Users/test/.sdkman/candidates/maven/4.0.0-rc-7", { "maven-core-4.0.0-rc-7.jar" })
-- A manual install in /opt, next to Homebrew's own directory, which is not a Maven home.
entries("/opt", { "homebrew", "apache-maven-3.6.3" })
maven("/opt/apache-maven-3.6.3", { "maven-core-3.6.3.jar" })
-- /usr/local holds a launcher of its own, which must not make /usr/local a home.
entries("/usr/local", { "bin", "opt" })
files[norm("/usr/local/bin/mvn")] = true

local found = detect.find_all()
local by_version = {}
for _, item in ipairs(found) do
    assert(by_version[item.version] == nil, "a version is listed once: " .. item.version)
    by_version[item.version] = item
end

assert(by_version["3.9.11"].path == "/opt/homebrew/opt/maven/libexec", by_version["3.9.11"].path)
assert(by_version["3.9.11"].note == "installed by Homebrew")
assert(by_version["3.8.8"].path == "/usr/local/opt/maven/libexec", by_version["3.8.8"].path)
assert(by_version["4.0.0-rc-7"].note == "installed by SDKMAN")
assert(by_version["3.6.3"].path == "/opt/apache-maven-3.6.3")
assert(by_version["3.6.3"].note == "in a system directory")
assert(#found == 4, "four Maven homes, got " .. #found)

print("PASS: detect finds the Maven homes of macOS, Homebrew kegs included")
