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

-- The Maven homes that `vfox link --detect maven` finds on Linux: where they are, how their
-- versions are named, and the ones it must leave out.
local test = require("vfox.test")
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {
        HOME = "/home/test",
        M2_HOME = "/home/test/tools/apache-maven-3.10.1",
        MAVEN_HOME = "/home/test/.vfox/sdks/maven",
    },
})
local detect = require("detect_maven")

-- The fake filesystem: the files that exist, the entries of each directory, and what each
-- Maven home prints for `mvn -v`.
local files = {}
local dirs = {}
local versions_out = {}

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

-- A handle as vfox's io.popen gives it on Windows: read and close, and no lines, so a
-- call of lines would fail here as it does there.
local function handle(lines, output)
    local index = 0
    return {
        read = function(_, format)
            if format == "*a" then
                return output
            end
            index = index + 1
            return lines[index]
        end,
        close = function()
            return true
        end,
    }
end

-- `mvn -v` answers with the output of the home it runs; `ls` lists a directory.
io.popen = function(cmd)
    local home = cmd:match("^'(.+)/bin/mvn' %-v")
    if home then
        return handle({}, versions_out[norm(home)] or "")
    end
    local dir = cmd:match("'([^']+)'") or cmd:match('"([^"]+)"')
    return handle(dirs[norm(dir or "")] or {}, "")
end

-- A Maven home at home, whose lib directory holds the file names given.
local function maven(home, lib)
    files[norm(home .. "/bin/mvn")] = true
    dirs[norm(home .. "/lib")] = lib or {}
end

-- The entries of a directory.
local function entries(dir, names)
    dirs[norm(dir)] = names
end

-- The version comes from the names of the files in lib: the core jar of Maven 3 and 4, the
-- uber jar of Maven 2. Debian's core jar has no patch number, and Maven 1's jar no version.
assert(detect.version_from_names({ "maven-core-3.10.1.jar", "aopalliance.jar" }) == "3.10.1")
assert(detect.version_from_names({ "maven-core-4.0.0-rc-7.jar" }) == "4.0.0-rc-7")
assert(detect.version_from_names({ "maven-2.2.1-uber.jar" }) == "2.2.1")
assert(detect.version_from_names({ "maven-2.0.11-uber.jar" }) == "2.0.11")
assert(detect.version_from_names({ "maven-core-3.x.jar" }) == nil)
assert(detect.version_from_names({ "maven.jar", "forehead-1.0-beta-5.jar" }) == nil)

-- `mvn -v` names the version on its first line, which may carry colour codes.
assert(detect.version_from_output("\27[1mApache Maven 3.9.9\27[m\nMaven home: /usr/share/maven\n") == "3.9.9")
assert(detect.version_from_output("Apache Maven 4.0.0-rc-7 (abc)\n") == "4.0.0-rc-7")
assert(detect.version_from_output("mvn: command not found\n") == nil)

-- Debian's core jar names no patch number, so the version comes from the launcher.
maven("/opt/debian-maven", { "maven-core-3.x.jar" })
assert(detect.version_of("/opt/debian-maven") == nil, "no output from the launcher, no version")
maven("/usr/share/maven", { "maven-core-3.x.jar" })
versions_out["/usr/share/maven"] = "Apache Maven 3.9.9\nMaven home: /usr/share/maven\n"
assert(detect.version_of("/usr/share/maven") == "3.9.9", "the version from mvn -v")

-- The layout of a machine: a Maven the user unpacked, Maven that the version managers
-- installed, a Homebrew keg, a system package and a manual install in /opt.
maven("/home/test/tools/apache-maven-3.10.1", { "maven-core-3.10.1.jar", "aopalliance.jar" })
-- vfox's own install is named by MAVEN_HOME, and must never be detected.
maven("/home/test/.vfox/sdks/maven", { "maven-core-3.9.0.jar" })
-- SDKMAN: `current` links to the version, so the same version is found twice.
entries("/home/test/.sdkman/candidates/maven", { "3.0.5", "current" })
maven("/home/test/.sdkman/candidates/maven/3.0.5", { "maven-core-3.0.5.jar" })
maven("/home/test/.sdkman/candidates/maven/current", { "maven-core-3.0.5.jar" })
entries("/home/test/.asdf/installs/maven", { "2.2.1" })
maven("/home/test/.asdf/installs/maven/2.2.1", { "maven-2.2.1-uber.jar" })
entries("/home/test/.local/share/mise/installs/maven", { "2.0.11" })
maven("/home/test/.local/share/mise/installs/maven/2.0.11", { "maven-2.0.11-uber.jar" })
-- A Homebrew keg keeps its Maven in libexec.
entries("/home/test/.linuxbrew/opt", { "maven" })
maven("/home/test/.linuxbrew/opt/maven/libexec", { "maven-core-4.0.0-rc-7.jar" })
maven("/usr/share/maven", { "maven-core-3.x.jar" })
entries("/opt", { "apache-maven-4.0.0-rc-7", "maven-1.1" })
maven("/opt/apache-maven-4.0.0-rc-7", { "maven-core-4.0.0-rc-7.jar" })
-- Maven 1 has a launcher named maven, not mvn, so it is not a home for this plugin.
files[norm("/opt/maven-1.1/bin/maven")] = true
dirs[norm("/opt/maven-1.1/lib")] = { "maven.jar" }
-- /usr/local is a root too, and a launcher directly in it must not make it a home.
entries("/usr/local", { "bin", "share" })
files[norm("/usr/local/bin/mvn")] = true

local found = detect.find_all()
local by_version = {}
for _, item in ipairs(found) do
    assert(by_version[item.version] == nil, "a version is listed once: " .. item.version)
    by_version[item.version] = item
end

assert(by_version["3.10.1"].path == "/home/test/tools/apache-maven-3.10.1")
assert(by_version["3.10.1"].note == "pointed to by M2_HOME")
assert(by_version["3.9.9"].path == "/usr/share/maven")
assert(by_version["3.9.9"].note == "system package")
assert(by_version["3.0.5"].path == "/home/test/.sdkman/candidates/maven/3.0.5", by_version["3.0.5"].path)
assert(by_version["3.0.5"].note == "installed by SDKMAN")
assert(by_version["2.2.1"].note == "installed by asdf")
assert(by_version["2.0.11"].note == "installed by mise")
assert(by_version["4.0.0-rc-7"].path == "/home/test/.linuxbrew/opt/maven/libexec", by_version["4.0.0-rc-7"].path)
assert(by_version["4.0.0-rc-7"].note == "installed by Homebrew")
assert(by_version["3.9.0"] == nil, "vfox's own install is not detected")
assert(by_version["1.1"] == nil, "Maven 1 names no version, so it is not detected")
assert(#found == 6, "six Maven homes, got " .. #found)

-- The hook returns what find_all finds, in the same order.
local hooked = plugin:Detect({})
assert(#hooked == #found, "the hook returns " .. #hooked .. " entries, want " .. #found)
for i, item in ipairs(found) do
    assert(hooked[i].version == item.version and hooked[i].path == item.path, "entry " .. i)
end

print("PASS: detect finds the Maven homes of Linux by their names and their launchers")
