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

--- Finds Maven installs that are already on the machine, for `vfox link --detect maven`.
---
--- A Maven home holds `bin/mvn` (`bin\mvn.cmd` on Windows), or `libexec/bin/mvn` for a
--- Homebrew keg. Its version is in the names of the files in `lib`: `maven-core-<version>.jar`
--- for Maven 3 and 4, `maven-<version>-uber.jar` for Maven 2. Debian and Ubuntu name the core
--- jar `maven-core-3.x.jar`, so on Linux the version then comes from `mvn -v`. Maven 1 names no
--- version in its files, so it is not found and is linked by hand.
local detect = {}

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_windows()
    return RUNTIME ~= nil and RUNTIME.osType == "windows"
end

--- Returns the separator for the current platform: `\` on Windows, `/` elsewhere.
local function sep()
    if is_windows() then
        return "\\"
    end
    return "/"
end

--- Joins two path segments with the platform separator.
function detect.join(left, right)
    local last = left:sub(-1)
    if last == "/" or last == "\\" then
        return left .. right
    end
    return left .. sep() .. right
end

--- Joins several path segments.
local function child(base, ...)
    local result = base
    for _, part in ipairs({ ... }) do
        result = detect.join(result, part)
    end
    return result
end

--- Returns the user's home directory, or "".
local function home_dir()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or ""
end

local function shell_quote(value)
    if is_windows() then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

--- Lists the names of the entries of dir, files and directories alike, or {}.
--- @param dir string
--- @return table The names, without the directory
function detect.list_names(dir)
    if dir == "" then
        return {}
    end
    local cmd
    if is_windows() then
        cmd = "dir /b " .. shell_quote(dir) .. " 2>nul"
    else
        cmd = "ls -1 " .. shell_quote(dir) .. " 2>/dev/null"
    end
    local handle = io.popen(cmd, "r")
    if not handle then
        return {}
    end
    local names = {}
    for line in handle:lines() do
        line = trim(line)
        if line ~= "" and line ~= "." and line ~= ".." then
            table.insert(names, line)
        end
    end
    handle:close()
    return names
end

--- Lists the immediate children of dir as full paths, or {}.
local function list_children(dir)
    local children = {}
    for _, name in ipairs(detect.list_names(dir)) do
        table.insert(children, detect.join(dir, name))
    end
    return children
end

local function exists(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

--- The launcher of a Maven home, relative to the home.
local function launcher()
    if is_windows() then
        return "bin\\mvn.cmd"
    end
    return "bin/mvn"
end

--- Returns the Maven home that dir is: dir itself, or the libexec of a Homebrew keg. nil otherwise.
local function maven_home(dir)
    if exists(detect.join(dir, launcher())) then
        return dir
    end
    local libexec = detect.join(dir, "libexec")
    if exists(detect.join(libexec, launcher())) then
        return libexec
    end
    return nil
end

--- The version that the names of the files in a lib directory give, or nil.
--- @param names table The names of the files in lib
--- @return string|nil
function detect.version_from_names(names)
    for _, name in ipairs(names) do
        local version = name:match("^maven%-core%-(%d+%.%d[%w%.%-]*)%.jar$")
            or name:match("^maven%-(%d+%.%d[%w%.%-]*)%-uber%.jar$")
        if version then
            return version
        end
    end
    return nil
end

--- The version in the output of `mvn -v`, which starts with "Apache Maven <version>".
--- The colour codes the output may carry are removed first.
--- @param output string
--- @return string|nil
function detect.version_from_output(output)
    local plain = (output or ""):gsub("\27%[[%d;]*%a", "")
    return plain:match("Apache Maven (%d[%w%.%-]*)")
end

--- Asks the launcher of a Maven home for its version. Only on Unix: the Windows launcher is a
--- batch file, and the version is read from the file names there.
local function version_by_launcher(home)
    if is_windows() then
        return nil
    end
    local handle = io.popen(shell_quote(detect.join(home, launcher())) .. " -v 2>/dev/null", "r")
    if not handle then
        return nil
    end
    local output = handle:read("*a")
    handle:close()
    return detect.version_from_output(output)
end

--- The version of a Maven home, or nil when neither its file names nor its launcher give one.
--- @param home string
--- @return string|nil
function detect.version_of(home)
    local names = detect.list_names(detect.join(home, "lib"))
    return detect.version_from_names(names) or version_by_launcher(home)
end

--- Whether a path is inside a `.vfox` directory: vfox's own installs, which must never be detected.
local function is_vfox_managed(path)
    local p = (path or ""):lower()
    return p:find("/.vfox/", 1, true) ~= nil or p:find("\\.vfox\\", 1, true) ~= nil
end

--- The roots to look in: {path, note, depth}. A root of depth 0 is a Maven home itself. A
--- root of depth 1 holds Maven homes as its immediate children, and depth 2 holds them one
--- level further down, where Scoop and Chocolatey put their packages.
function detect.candidate_roots()
    local roots = {}
    local function add(path, note, depth)
        if type(path) == "string" and path ~= "" then
            table.insert(roots, { path = path, note = note, depth = depth })
        end
    end

    local home = home_dir()
    add(os.getenv("M2_HOME"), "pointed to by M2_HOME", 0)
    add(os.getenv("MAVEN_HOME"), "pointed to by MAVEN_HOME", 0)

    if is_windows() then
        local userprofile = os.getenv("USERPROFILE") or home
        local programfiles = os.getenv("ProgramFiles") or "C:\\Program Files"
        local programdata = os.getenv("ProgramData") or "C:\\ProgramData"
        add(child(userprofile, ".asdf", "installs", "maven"), "installed by asdf", 1)
        add(child(userprofile, ".local", "share", "mise", "installs", "maven"), "installed by mise", 1)
        add(child(userprofile, "scoop", "apps", "maven"), "installed by Scoop", 2)
        add(child(programdata, "chocolatey", "lib", "maven"), "installed by Chocolatey", 2)
        add(child(programfiles, "Apache"), "in a system directory", 1)
        add(programfiles, "in a system directory", 1)
        return roots
    end

    add(child(home, ".sdkman", "candidates", "maven"), "installed by SDKMAN", 1)
    add(child(home, ".asdf", "installs", "maven"), "installed by asdf", 1)
    add(child(home, ".local", "share", "mise", "installs", "maven"), "installed by mise", 1)

    if RUNTIME and RUNTIME.osType == "darwin" then
        add("/opt/homebrew/opt", "installed by Homebrew", 1)
        add("/usr/local/opt", "installed by Homebrew", 1)
        add("/opt", "in a system directory", 1)
        add("/usr/local", "in a system directory", 1)
        return roots
    end

    add(child(home, ".linuxbrew", "opt"), "installed by Homebrew", 1)
    add("/home/linuxbrew/.linuxbrew/opt", "installed by Homebrew", 1)
    add("/usr/share/maven", "system package", 0)
    add("/opt", "in a system directory", 1)
    add("/usr/local", "in a system directory", 1)
    return roots
end

--- Records the Maven home found, with its version, unless it was recorded already.
local function add_home(home, note, seen, out)
    if seen[home] then
        return
    end
    seen[home] = true
    local version = detect.version_of(home)
    if version then
        table.insert(out, { version = version, path = home, note = note })
    end
end

--- Records the Maven homes that are the children of dir, nested as deep as depth allows.
local function scan_children(dir, note, depth, seen, out)
    for _, entry in ipairs(list_children(dir)) do
        local found = maven_home(entry)
        if found then
            add_home(found, note, seen, out)
        elseif depth > 1 then
            scan_children(entry, note, depth - 1, seen, out)
        end
    end
end

--- Finds every Maven home on the machine that vfox did not install. Each entry names the
--- version the way `vfox install` names it. Results are sorted by version then path, and each
--- version appears once, the first path of it.
--- @return table Entries of {version, path, note}
function detect.find_all()
    local out = {}
    local seen = {}
    for _, root in ipairs(detect.candidate_roots()) do
        if not is_vfox_managed(root.path) then
            if root.depth == 0 then
                local found = maven_home(root.path)
                if found then
                    add_home(found, root.note, seen, out)
                end
            else
                scan_children(root.path, root.note, root.depth, seen, out)
            end
        end
    end

    local filtered = {}
    for _, item in ipairs(out) do
        if not is_vfox_managed(item.path) then
            table.insert(filtered, item)
        end
    end
    table.sort(filtered, function(a, b)
        if a.version ~= b.version then
            return a.version < b.version
        end
        return a.path < b.path
    end)
    -- vfox links the first entry of a version and skips the rest as already linked.
    local result = {}
    local seen_versions = {}
    for _, item in ipairs(filtered) do
        if not seen_versions[item.version] then
            seen_versions[item.version] = true
            table.insert(result, item)
        end
    end
    return result
end

return detect
