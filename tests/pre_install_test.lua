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

-- The answers to the plugin's requests, by URL: the body of a file, or an error
-- the request fails with. A URL with no answer is a 404.
local answers = {}
local plugin = test.load({
    http = function(request)
        local answer = answers[request.url]
        if answer == nil then
            return { status_code = 404, body = "" }
        end
        if type(answer) == "table" then
            return nil, answer.err
        end
        return { status_code = 200, body = answer }
    end,
})

local CURRENT = "https://dlcdn.apache.org/maven/"
local ARCHIVE = "https://archive.apache.org/dist/maven/"

-- The archive of a release at a source, laid out as both sources lay them out.
local function archive(source, major, version)
    return source .. ("maven-%s/%s/binaries/apache-maven-%s-bin.tar.gz"):format(major, version, version)
end

-- The directory listing of a major version at dlcdn.apache.org, naming the given releases.
local function listing(versions)
    local links = { '<a href="../">../</a>' }
    for _, v in ipairs(versions) do
        table.insert(links, ('<a href="%s/">%s/</a>'):format(v, v))
    end
    return "<html><body>" .. table.concat(links, "\n") .. "</body></html>"
end

local SHA512 = ("a"):rep(128)
local SHA512_OTHER = ("d"):rep(128)
local SHA1 = ("b"):rep(40)
local MD5 = ("c"):rep(32)

local cases = 0

-- Checks that PreInstall(version) fails with an error that contains text.
local function fails(version, text)
    local ok, err = pcall(function()
        return plugin:PreInstall({ version = version })
    end)
    assert(not ok, version .. ": expected an error")
    assert(tostring(err):find(text, 1, true), tostring(err))
    cases = cases + 1
end

-- A current release that dlcdn.apache.org lists. Its strongest checksum is used,
-- though its .sha1 file is there too.
answers[CURRENT .. "maven-3/"] = listing({ "3.10.1", "3.9.16" })
answers[archive(CURRENT, "3", "3.10.1") .. ".sha512"] = SHA512 .. "\n"
answers[archive(CURRENT, "3", "3.10.1") .. ".sha1"] = SHA1 .. "\n"
local result = plugin:PreInstall({ version = "3.10.1" })
assert(result.version == "3.10.1", result.version)
assert(result.url == archive(CURRENT, "3", "3.10.1"), result.url)
assert(result.sha512 == SHA512, result.sha512)
-- A field the result lacks comes back as "" from vfox's test harness, not nil.
assert(result.sha1 == nil or result.sha1 == "", "only the strongest checksum is given")
cases = cases + 1

-- 3.9.11 is not in the listing of dlcdn.apache.org, but a checksum file there
-- redirects to the archive. The archive is the source, and the checksum is the
-- archive's, not the one that the redirect gave.
answers[archive(CURRENT, "3", "3.9.11") .. ".sha512"] = SHA512_OTHER .. "\n"
answers[archive(ARCHIVE, "3", "3.9.11") .. ".sha512"] = SHA512 .. "\n"
result = plugin:PreInstall({ version = "3.9.11" })
assert(result.url == archive(ARCHIVE, "3", "3.9.11"), result.url)
assert(result.sha512 == SHA512, result.sha512)
cases = cases + 1

-- An old release that dlcdn.apache.org does not list comes from the archive, with
-- the .sha1 file that old release has.
answers[archive(ARCHIVE, "3", "3.0.5") .. ".sha1"] = SHA1 .. "\n"
result = plugin:PreInstall({ version = "3.0.5" })
assert(result.url == archive(ARCHIVE, "3", "3.0.5"), result.url)
assert(result.sha1 == SHA1, result.sha1)
cases = cases + 1

-- Maven 2 has no release listed at dlcdn.apache.org, and its .md5 is written the BSD way.
answers[archive(ARCHIVE, "2", "2.2.1") .. ".md5"] = "MD5 (apache-maven-2.2.1-bin.tar.gz) = " .. MD5
result = plugin:PreInstall({ version = "2.2.1" })
assert(result.version == "2.2.1", result.version)
assert(result.url == archive(ARCHIVE, "2", "2.2.1"), result.url)
assert(result.md5 == MD5, result.md5)
cases = cases + 1

-- A pre-release that dlcdn.apache.org lists keeps its name in the address.
answers[CURRENT .. "maven-4/"] = listing({ "4.0.0-rc-7" })
answers[archive(CURRENT, "4", "4.0.0-rc-7") .. ".sha512"] = SHA512 .. "\n"
result = plugin:PreInstall({ version = "4.0.0-rc-7" })
assert(result.version == "4.0.0-rc-7", result.version)
assert(result.url == archive(CURRENT, "4", "4.0.0-rc-7"), result.url)
cases = cases + 1

-- The listing decides where the archive comes from, so a listing that cannot be
-- read fails the install.
answers[CURRENT .. "maven-3/"] = { err = "dial tcp: i/o timeout" }
fails("3.10.1", "dial tcp: i/o timeout")

-- A release that neither source has: it is not listed, and has no checksum at the archive.
fails("4.0.0-alpha-99", "Maven 4.0.0-alpha-99 has no checksum file at " .. ARCHIVE)

-- Maven 1 has a layout of its own, and its only checksum is a .md5 that writes the
-- digest in byte pairs after the file name.
local MAVEN_1_MD5 = ARCHIVE .. "maven-1/1.1/binaries/maven-1.1.tar.gz.md5"
answers[MAVEN_1_MD5] = "maven-1.1.tar.gz: EC 2B 0A D8 C7 8B A5 24  97 F6 3E E7 F6 13 B5 26\n"
result = plugin:PreInstall({ version = "1.1" })
assert(result.version == "1.1", result.version)
assert(result.url == ARCHIVE .. "maven-1/1.1/binaries/maven-1.1.tar.gz", result.url)
assert(result.md5 == "ec2b0ad8c78ba52497f63ee7f613b526", result.md5)
cases = cases + 1

-- Only Maven 1 to 4 are known.
fails("0.9", "invalid version: 0.9")
fails("abc", "invalid version: abc")
fails("", "invalid version: ")

print("PASS: " .. cases .. " install cases")
