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
	"io/fs"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// historical are releases that only archive.apache.org keeps, and each of them uses a
// layout that the plugin reads: 3.0.5 and 2.2.1 the usual one, 1.1 the one of Maven 1.
var historical = []string{"3.0.5", "2.2.1", "1.1"}

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

// launcherNames returns the names of the command that runs Maven, in the order of
// preference. Maven 1 runs as maven, Maven 2 to 4 as mvn, and Windows has batch files
// for both.
func launcherNames(major string, windows bool) []string {
	command := "mvn"
	if major == "1" {
		command = "maven"
	}
	if windows {
		return []string{command + ".cmd", command + ".bat"}
	}
	return []string{command}
}

// findLauncher returns the launcher of an installed Maven: the file named by the first of
// names that is found in a bin directory under root. The launchers are searched for under
// root because a release unpacks into a directory of its own.
func findLauncher(root string, names []string) (string, error) {
	found, rank := "", len(names)
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() || filepath.Base(filepath.Dir(path)) != "bin" {
			return nil
		}
		if i := slices.Index(names, entry.Name()); i >= 0 && i < rank {
			found, rank = path, i
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	if found == "" {
		return "", fmt.Errorf("none of %v in a bin directory under %s", names, root)
	}
	return found, nil
}
