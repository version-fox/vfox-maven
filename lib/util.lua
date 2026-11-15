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

local html = require("html")
local http = require("http")
local util = {}

-- Where the releases are published. dlcdn.apache.org is a mirror network that
-- lists the current releases; archive.apache.org keeps every release, the old
-- ones too. Both lay the releases out the same way.
util.CURRENT = "https://dlcdn.apache.org/maven/"
util.ARCHIVE = "https://archive.apache.org/dist/maven/"
util.SOURCES = { util.CURRENT, util.ARCHIVE }

-- The major versions the plugin installs. Maven 1 has a layout of its own (see
-- archiveURL): its one release, 1.1, runs as `maven`, not `mvn`.
util.MAJORS = { "1", "2", "3", "4" }

-- The checksum files Apache publishes beside an archive, the strongest first,
-- with the length of their digests in hexadecimal digits. Older releases publish
-- a .sha1 or a .md5 file instead of a .sha512.
util.ALGORITHMS = {
    { name = "sha512", length = 128 },
    { name = "sha1", length = 40 },
    { name = "md5", length = 32 },
}

--- The address of the archive of a release at a source.
--- @param source string One of util.SOURCES
--- @param major string 2, 3 or 4
--- @param version string The release, such as 3.10.1
--- @return string
function util:archiveURL(source, major, version)
    if major == "1" then
        -- Maven 1 names its archive after itself, not apache-maven-<version>-bin.
        return source .. ("maven-1/%s/binaries/maven-%s.tar.gz"):format(version, version)
    end
    return source .. ("maven-%s/%s/binaries/apache-maven-%s-bin.tar.gz"):format(major, version, version)
end

--- The major version of a version the plugin installs, or nil for any other.
--- @param version string
--- @return string|nil
function util:majorOf(version)
    local major = string.sub(version, 1, 1)
    for _, known in ipairs(util.MAJORS) do
        if major == known then
            return major
        end
    end
    return nil
end

--- Lists the releases in one directory listing of a source, such as maven-3/ at
--- dlcdn.apache.org. A directory that the source does not have lists nothing.
--- @param url string The address of the listing
--- @return table Descriptions of the releases, as Available returns them
function util:parseVersion(url)
    local resp, err = http.get({
        url = url,
    })
    if err == nil and resp.status_code == 404 then
        return {}
    end
    if err ~= nil or resp.status_code ~= 200 then
        local reason = err or ("HTTP status " .. tostring(resp.status_code))
        error("parsing release info failed for " .. url .. ": " .. reason)
    end
    local result = {}
    html.parse(resp.body):find("a"):each(function(i, selection)
        local href = selection:attr("href")
        local sn = string.match(href, "^%d")
        local es = string.match(href, "/$")
        if sn and es then
            table.insert(result, {
                version = string.sub(href, 1, -2),
                note = "",
            })
        end
    end)
    return result
end

--- The source that serves a release: dlcdn.apache.org when it lists the release,
--- archive.apache.org otherwise. The choice follows the listing, not the checksum
--- files: dlcdn.apache.org redirects the checksum files of some older releases to
--- the archive, and the archive they name is not on dlcdn.apache.org.
--- @param major string 2, 3 or 4
--- @param version string The release, such as 3.9.11
--- @return string One of util.SOURCES
function util:sourceOf(major, version)
    for _, release in ipairs(util:parseVersion(util.CURRENT .. ("maven-%s/"):format(major))) do
        if release.version == version then
            return util.CURRENT
        end
    end
    return util.ARCHIVE
end

--- Lists the releases of a major version that any source has, each once.
--- @param major string 2, 3 or 4
--- @return table Descriptions of the releases, as Available returns them
function util:listVersions(major)
    local seen = {}
    local result = {}
    for _, source in ipairs(util.SOURCES) do
        for _, release in ipairs(util:parseVersion(source .. ("maven-%s/"):format(major))) do
            if not seen[release.version] then
                seen[release.version] = true
                table.insert(result, release)
            end
        end
    end
    return result
end

--- Finds the digest in a checksum file, however the file writes it: the digest
--- alone, "<digest>  <name>", BSD's "MD5 (<name>) = <digest>", or Maven 1's
--- "<name>: EC 2B 0A ..." with the digest in byte pairs.
--- @param body string The contents of the file
--- @param length number The length of the digest in hexadecimal digits
--- @return string|nil The digest in lower case, or nil if the file has none
function util:digestIn(body, length)
    for word in body:gmatch("%x+") do
        if #word == length then
            return word:lower()
        end
    end
    local bytes = body:match(":(.*)")
    if bytes ~= nil then
        local digest = bytes:gsub("%s", "")
        if #digest == length and digest:match("^%x+$") then
            return digest:lower()
        end
    end
    return nil
end

--- Reads the digest from one checksum file of an archive.
--- @param url string The address of the checksum file
--- @param length number The length of the digest in hexadecimal digits
--- @return string|nil The digest, or nil when the source has no such file
function util:fetchDigest(url, length)
    local resp, err = http.get({
        url = url,
    })
    if err == nil and resp.status_code == 404 then
        return nil
    end
    if err ~= nil or resp.status_code ~= 200 then
        local reason = err or ("HTTP status " .. tostring(resp.status_code))
        error("reading the checksum failed for " .. url .. ": " .. reason)
    end
    local digest = util:digestIn(resp.body, length)
    if digest == nil then
        error("no digest in " .. url)
    end
    return digest
end

return util
