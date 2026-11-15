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
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// checkSystemMaven checks the other way a Maven gets into vfox: a Maven that is already on the
// machine and that vfox did not install. vfox link --detect finds the Maven home that M2_HOME
// names, links it as a version, and vfox use selects that version, so the Maven command runs it.
// The home is a copy of an installed release, kept outside vfox's directories, so it stands for a
// Maven that the user unpacked. The vfox home of the check holds nothing else.
func checkSystemMaven(t *testing.T, binary, zipPath, source string) {
	t.Helper()
	const version = archivedMaven3
	home := filepath.Join(tempDir(t), "apache-maven-"+version)
	if err := copyTree(source, home); err != nil {
		t.Fatalf("copy %s to %s: %v", source, home, err)
	}
	v := vfox{binary: binary, home: tempDir(t)}
	if out, err := v.run("add", "maven", "--source", zipPath); err != nil {
		t.Fatalf("vfox add maven: %v\n%s", err, out)
	}

	out, err := v.runWith([]string{"M2_HOME=" + home}, "link", "--detect", "-y", "maven")
	if err != nil {
		t.Fatalf("vfox link --detect -y maven: %v\n%s", err, out)
	}
	if !strings.Contains(out, "maven@"+version) || !strings.Contains(out, home) {
		t.Fatalf("vfox link --detect does not find %s at %s:\n%s", version, home, out)
	}
	list, err := v.run("list", "maven")
	if err != nil {
		t.Fatalf("vfox list maven: %v\n%s", err, list)
	}
	if !strings.Contains(list, version) || !strings.Contains(list, "linked") || !strings.Contains(list, home) {
		t.Fatalf("vfox list maven does not show %s linked to %s:\n%s", version, home, list)
	}

	selected := runOne(t, scenario{
		home:     v.home,
		dir:      v.home,
		launcher: "mvn",
		steps:    []step{{use: []string{"--global", "maven@" + version}}, {report: true}},
	})
	checkReport(t, selected, version, globalDir(v.home))
}

// mavenHomeOf returns the Maven home inside the install directory that vfox reports for a
// release. The release unpacks into maven-<version> there; the directory itself is the home when
// that is not so.
func mavenHomeOf(install, version string) string {
	home := filepath.Join(install, "maven-"+version)
	if info, err := os.Stat(filepath.Join(home, "bin")); err == nil && info.IsDir() {
		return home
	}
	return install
}

// copyTree copies the directory src to dst: its directories, its files with their modes, and its
// symbolic links as they are, without following them.
func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		info, err := entry.Info()
		if err != nil {
			return err
		}
		switch {
		case entry.IsDir():
			return os.MkdirAll(target, 0o755)
		case info.Mode()&fs.ModeSymlink != 0:
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		case info.Mode().IsRegular():
			data, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			return os.WriteFile(target, data, info.Mode().Perm())
		default:
			return fmt.Errorf("%s is neither a file, a directory nor a link", path)
		}
	})
}
