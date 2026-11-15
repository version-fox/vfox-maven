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

-- The Maven homes that `vfox link --detect maven` finds on Windows: the launcher is mvn.cmd,
-- Scoop and Chocolatey nest their packages, and a Maven whose jar names no version is left out,
-- as there is no launcher to ask for it.
local test = require("vfox.test")
local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {
        USERPROFILE = "C:\\Users\\test",
        ProgramFiles = "C:\\Program Files",
        ProgramData = "C:\\ProgramData",
        M2_HOME = "C:\\tools\\apache-maven-3.10.1",
        MAVEN_HOME = "C:\\Users\\test\\.vfox\\sdks\\maven",
    },
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

-- A handle as vfox's io.popen gives it on Windows: read and close, and no lines.
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
    files[norm(home .. "/bin/mvn.cmd")] = true
    dirs[norm(home .. "/lib")] = lib or {}
end

local function entries(dir, names)
    dirs[norm(dir)] = names
end

-- The Maven that the user unpacked, named by M2_HOME.
maven("C:\\tools\\apache-maven-3.10.1", { "maven-core-3.10.1.jar" })
-- vfox's own install, named by MAVEN_HOME: never detected.
maven("C:\\Users\\test\\.vfox\\sdks\\maven", { "maven-core-3.9.0.jar" })
-- Scoop: one directory per app, with the versions beneath it and `current` linking to one.
entries("C:\\Users\\test\\scoop\\apps\\maven", { "3.9.11", "current" })
maven("C:\\Users\\test\\scoop\\apps\\maven\\3.9.11", { "maven-core-3.9.11.jar" })
maven("C:\\Users\\test\\scoop\\apps\\maven\\current", { "maven-core-3.9.11.jar" })
-- Chocolatey: the package holds a tools directory, which holds the Maven.
entries("C:\\ProgramData\\chocolatey\\lib\\maven", { "tools" })
entries("C:\\ProgramData\\chocolatey\\lib\\maven\\tools", { "apache-maven-3.8.8" })
maven("C:\\ProgramData\\chocolatey\\lib\\maven\\tools\\apache-maven-3.8.8", { "maven-core-3.8.8.jar" })
-- asdf and mise on Windows.
entries("C:\\Users\\test\\.asdf\\installs\\maven", { "4.0.0-rc-7" })
maven("C:\\Users\\test\\.asdf\\installs\\maven\\4.0.0-rc-7", { "maven-core-4.0.0-rc-7.jar" })
-- A manual install under Program Files.
entries("C:\\Program Files", { "apache-maven-3.6.3", "Java" })
maven("C:\\Program Files\\apache-maven-3.6.3", { "maven-core-3.6.3.jar" })
-- Debian-style names give no version on Windows, so this Maven is not found.
entries("C:\\Program Files\\Apache", { "Maven" })
maven("C:\\Program Files\\Apache\\Maven", { "maven-core-3.x.jar" })

local found = detect.find_all()
local by_version = {}
for _, item in ipairs(found) do
    assert(by_version[item.version] == nil, "a version is listed once: " .. item.version)
    by_version[item.version] = item
end

assert(by_version["3.10.1"].path == "C:\\tools\\apache-maven-3.10.1")
assert(by_version["3.10.1"].note == "pointed to by M2_HOME")
assert(by_version["3.9.11"].path == "C:\\Users\\test\\scoop\\apps\\maven\\3.9.11", by_version["3.9.11"].path)
assert(by_version["3.9.11"].note == "installed by Scoop")
assert(by_version["3.8.8"].path == "C:\\ProgramData\\chocolatey\\lib\\maven\\tools\\apache-maven-3.8.8")
assert(by_version["3.8.8"].note == "installed by Chocolatey")
assert(by_version["4.0.0-rc-7"].note == "installed by asdf")
assert(by_version["3.6.3"].note == "in a system directory")
assert(by_version["3.9.0"] == nil, "vfox's own install is not detected")
assert(#found == 5, "five Maven homes, got " .. #found)

print("PASS: detect finds the Maven homes of Windows by their names, Scoop and Chocolatey included")
