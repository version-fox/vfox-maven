#!/usr/bin/env bash
# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The end-to-end check of the plugin, described in docs/e2e.md. It zips the
# plugin and adds it to vfox, then installs the newest Maven 3 and the newest
# Maven 4 release that `vfox search maven` lists. Each install must verify its
# checksum, and mvn, found through vfox's environment, must report that version.
#
# Usage: run.sh [plugin directory]
#   The default is the repository this script belongs to. The run needs vfox,
#   zip, a Java runtime, and network access to dlcdn.apache.org.

set -o errexit -o nounset -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="${1:-$(cd "$script_dir/../.." && pwd)}"

work="$(mktemp --directory)"
trap 'rm --recursive --force "$work"' EXIT

# vfox keeps the SDK links and .vfox.toml under $HOME even when VFOX_HOME is
# set, so this run gets a HOME of its own and leaves the user's global
# selections alone.
export HOME="$work/home"
unset VFOX_HOME
mkdir --parents "$HOME"

# `vfox use` refuses to run unless a shell has loaded vfox's hook, which an
# interactive shell does with `vfox activate bash`. This script is not one, so
# it loads the hook the same way.
eval "$(vfox activate bash)"

(cd "$plugin_dir" && zip --quiet --recurse-paths "$work/maven.zip" metadata.lua hooks lib)
vfox add maven --source "$work/maven.zip"

vfox search maven > "$work/search.txt"
# Each release is listed as " - <version>", newest first within a major.
newest() {
    sed --quiet 's/^ - //p' "$work/search.txt" | grep --max-count=1 "^$1[.]" || true
}
maven3="$(newest 3)"
maven4="$(newest 4)"
if [[ -z "$maven3" || -z "$maven4" ]]; then
    echo "vfox search maven lists no Maven 3 or no Maven 4 release:" >&2
    cat "$work/search.txt" >&2
    exit 1
fi
# Two releases that only archive.apache.org has: dlcdn.apache.org keeps no old
# release, so these two check the archive path, for Maven 3 and for Maven 2.
historical="3.0.5 2.2.1"
for version in $historical; do
    if ! grep --quiet --line-regexp --fixed-strings " - $version" "$work/search.txt"; then
        echo "vfox search maven does not list $version, which the archive has:" >&2
        cat "$work/search.txt" >&2
        exit 1
    fi
done
echo "Newest releases listed: Maven 3 is $maven3, Maven 4 is $maven4; archived: $historical"

# check VERSION installs VERSION, which must verify its checksum, and then runs
# the mvn that vfox's environment selects, which must be that version.
check() {
    local version="$1"
    local log="$work/install-$version.log"
    vfox install "maven@$version" 2>&1 | tee "$log" > /dev/null
    grep --quiet "Verifying checksum" "$log"
    ! grep --quiet "Checksum is not provided" "$log"
    vfox use --global "maven@$version"
    (
        eval "$(vfox env --shell bash)"
        test "$(command -v mvn)" = "$HOME/.vfox/sdks/maven/bin/mvn"
        output="$(mvn --version)"
        grep --quiet --fixed-strings "Apache Maven $version " <<<"$output"
    )
    echo "PASS: maven@$version installs with its checksum verified, and mvn reports $version"
}

check "$maven3"
check "$maven4"
for version in $historical; do
    check "$version"
done
