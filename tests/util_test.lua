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

-- What each URL answers: a response, and the error a request fails with. A URL
-- with no answer is a 404, as Apache answers for a release it does not have.
local answers = {}
test.load({
    http = function(request)
        local answer = answers[request.url]
        if answer == nil then
            return { status_code = 404, body = "" }
        end
        return answer.response, answer.err
    end,
})
local util = require("util")

local DLCDN_3 = "https://dlcdn.apache.org/maven/maven-3/"
local ARCHIVE_3 = "https://archive.apache.org/dist/maven/maven-3/"
local ARCHIVE_3_0_5 = "https://archive.apache.org/dist/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz"
-- The digests of apache-maven-3.0.5-bin.tar.gz, as Apache publishes them.
local SHA1 = "aecc0d3d67732939c0056d4a0d8510483ee1167e"
local MD5 = "94c51f0dd139b4b8549204d0605a5859"

local cases = 0

-- Checks that fn fails with an error that contains text.
local function fails(fn, text)
    local ok, err = pcall(fn)
    assert(not ok, "expected an error containing " .. text)
    assert(tostring(err):find(text, 1, true), tostring(err))
    cases = cases + 1
end

-- A listing: the versions are the links whose names start with a digit and end with a slash.
answers[DLCDN_3] = {
    response = {
        status_code = 200,
        body = [[
<html><body>
<a href="../">../</a>
<a href="3.10.1/">3.10.1/</a>
<a href="3.9.16/">3.9.16/</a>
<a href="maven-metadata.xml">maven-metadata.xml</a>
</body></html>
]],
    },
}
local found = util:parseVersion(DLCDN_3)
assert(#found == 2 and found[1].version == "3.10.1" and found[2].version == "3.9.16", "unexpected listing")
cases = cases + 1

-- A directory the source does not have lists nothing.
assert(#util:parseVersion(ARCHIVE_3) == 0, "a missing directory must list nothing")
cases = cases + 1

-- A status other than 200 or 404 fails with the status.
answers[ARCHIVE_3] = { response = { status_code = 503, body = "" } }
fails(function()
    return util:parseVersion(ARCHIVE_3)
end, "parsing release info failed for " .. ARCHIVE_3 .. ": HTTP status 503")

-- A request that fails fails with its error. The HTTP module words the error
-- itself, so only the error's text is checked here.
answers[ARCHIVE_3] = { err = "dial tcp: i/o timeout" }
fails(function()
    return util:parseVersion(ARCHIVE_3)
end, "dial tcp: i/o timeout")

-- The digest in each way a checksum file writes it, and in upper case.
assert(util:digestIn(SHA1 .. "\n", 40) == SHA1, "a bare digest")
assert(util:digestIn(SHA1 .. "  apache-maven-3.0.5-bin.tar.gz\n", 40) == SHA1, "a digest and a file name")
assert(util:digestIn("MD5 (apache-maven-3.0.5-bin.tar.gz) = " .. MD5, 32) == MD5, "BSD's style")
assert(util:digestIn(MD5:upper(), 32) == MD5, "an upper case digest")
-- The length tells the digests apart: a SHA-1 is not an MD5.
assert(util:digestIn(SHA1, 32) == nil, "a digest of another length")
assert(util:digestIn("<html>no digest here</html>", 40) == nil, "a file with no digest")
cases = cases + 6

-- A checksum file that is missing is no digest; one that has none is an error.
assert(util:fetchDigest(ARCHIVE_3_0_5 .. ".sha512", 128) == nil, "a missing file")
cases = cases + 1
answers[ARCHIVE_3_0_5 .. ".sha1"] = { response = { status_code = 200, body = SHA1 .. "\n" } }
assert(util:fetchDigest(ARCHIVE_3_0_5 .. ".sha1", 40) == SHA1, "a checksum file")
cases = cases + 1
answers[ARCHIVE_3_0_5 .. ".md5"] = { response = { status_code = 200, body = "<html>oops</html>" } }
fails(function()
    return util:fetchDigest(ARCHIVE_3_0_5 .. ".md5", 32)
end, "no digest in " .. ARCHIVE_3_0_5 .. ".md5")

print("PASS: " .. cases .. " release listing and checksum cases")
