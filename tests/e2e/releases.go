// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package e2e

import (
	"bufio"
	"fmt"
	"regexp"
	"strings"
)

// archivedMaven3 is a Maven 3 release that only archive.apache.org keeps.
const archivedMaven3 = "3.0.5"

// historical are releases that only archive.apache.org keeps, and each of them uses a
// layout that the plugin reads: 3.0.5 and 2.2.1 the usual one, 2.0.11 its zip, and 1.1 the one
// of Maven 1.
var historical = []string{archivedMaven3, "2.2.1", "2.0.11", "1.1"}

// listingLine matches one release in the output of vfox search maven: " - <version>".
var listingLine = regexp.MustCompile(`^\s*-\s+(\S+)\s*$`)

// parseListing returns the releases that the output of vfox search maven lists, in the
// order that vfox prints them, which is newest first.
func parseListing(output string) []string {
	var versions []string
	scanner := bufio.NewScanner(strings.NewReader(output))
	for scanner.Scan() {
		if match := listingLine.FindStringSubmatch(scanner.Text()); match != nil {
			versions = append(versions, match[1])
		}
	}
	return versions
}

// majorOf returns the major version of a release: 3 for 3.10.1.
func majorOf(version string) string {
	major, _, _ := strings.Cut(version, ".")
	return major
}

// newestOf returns the first release of a major version in the listing. vfox prints the
// listing newest first, so that is the newest release of the major version.
func newestOf(versions []string, major string) (string, error) {
	for _, version := range versions {
		if majorOf(version) == major {
			return version, nil
		}
	}
	return "", fmt.Errorf("vfox search maven lists no Maven %s release", major)
}

// launcherCommand returns the name of the command that runs Maven: maven for Maven 1, and
// mvn for Maven 2 to 4.
func launcherCommand(major string) string {
	if major == "1" {
		return "maven"
	}
	return "mvn"
}
