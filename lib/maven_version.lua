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

--- Orders Maven versions the way its releases come. The numbers before the first
--- dash compare as numbers, so 3.10.1 is after 3.9.16. A release is after the
--- pre-releases of the same numbers, so 4.0.0 is after 4.0.0-rc-7. After the dash,
--- words and numbers compare piece by piece, so beta is before rc and rc-10 after rc-3.
local maven_version = {}

-- Returns the numbers before the first dash, and the rest of the version:
-- 4.0.0-rc-3 gives {4, 0, 0} and "-rc-3".
local function parts(version)
    local base, rest = version:match("^([^-]*)(.*)$")
    local numbers = {}
    for piece in (base .. "."):gmatch("(.-)%.") do
        table.insert(numbers, tonumber(piece) or 0)
    end
    return numbers, rest
end

-- Cuts a suffix into its words and numbers: "-rc-10" gives "-rc-" and 10.
local function pieces(suffix)
    local result = {}
    local rest = suffix
    while rest ~= "" do
        local number = rest:match("^%d+")
        if number then
            table.insert(result, tonumber(number))
            rest = rest:sub(#number + 1)
        else
            local word = rest:match("^%D+")
            table.insert(result, word)
            rest = rest:sub(#word + 1)
        end
    end
    return result
end

-- Compares two lists of pieces. A word sorts before a number, and a list that
-- runs out first sorts before one that goes on.
local function compare_pieces(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i], b[i]
        if x == nil then
            return -1
        end
        if y == nil then
            return 1
        end
        if type(x) ~= type(y) then
            return type(x) == "string" and -1 or 1
        end
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

--- Compares two Maven versions.
--- @param a string A version, such as 3.10.1 or 4.0.0-rc-7
--- @param b string Another version
--- @return number -1, 0 or 1 as a comes before, the same as, or after b
function maven_version.compare(a, b)
    local numbers_a, rest_a = parts(a)
    local numbers_b, rest_b = parts(b)
    for i = 1, math.max(#numbers_a, #numbers_b) do
        local x, y = numbers_a[i] or 0, numbers_b[i] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    if rest_a == rest_b then
        return 0
    end
    if rest_a == "" then
        return 1
    end
    if rest_b == "" then
        return -1
    end
    return compare_pieces(pieces(rest_a), pieces(rest_b))
end

--- Tells whether a Maven version is a pre-release: one with words after its numbers, such as
--- 4.0.0-rc-7 or 3.5.0-beta-1. A release has nothing after its numbers.
--- @param version string A version, such as 3.10.1 or 4.0.0-rc-7
--- @return boolean True when the version is a pre-release
function maven_version.is_prerelease(version)
    local _, rest = parts(version)
    return rest ~= ""
end

return maven_version
