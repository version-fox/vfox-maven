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
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestParseListing(t *testing.T) {
	output := "Available versions:\r\n - 4.0.0-rc-7\r\n - 3.10.1\r\n\r\nnot a release\r\n - 2.0.11\r\n"
	got := parseListing(output)
	want := []string{"4.0.0-rc-7", "3.10.1", "2.0.11"}
	if !slices.Equal(got, want) {
		t.Fatalf("parseListing = %v, want %v", got, want)
	}
}

func TestMajorOf(t *testing.T) {
	for version, want := range map[string]string{"3.10.1": "3", "4.0.0-rc-7": "4", "1.1": "1"} {
		if got := majorOf(version); got != want {
			t.Errorf("majorOf(%s) = %s, want %s", version, got, want)
		}
	}
}

func TestNewestOf(t *testing.T) {
	listed := []string{"4.0.0-rc-7", "4.0.0-alpha-2", "3.10.1", "3.0.5", "2.2.1", "1.1"}
	for major, want := range map[string]string{"4": "4.0.0-rc-7", "3": "3.10.1", "2": "2.2.1", "1": "1.1"} {
		got, err := newestOf(listed, major)
		if err != nil || got != want {
			t.Errorf("newestOf(%s) = %q, %v; want %q", major, got, err, want)
		}
	}
	if _, err := newestOf(listed, "5"); err == nil {
		t.Error("newestOf for a major version with no release must fail")
	}
}

func TestLauncherNames(t *testing.T) {
	cases := []struct {
		major   string
		windows bool
		want    []string
	}{
		{"1", false, []string{"maven"}},
		{"3", false, []string{"mvn"}},
		{"1", true, []string{"maven.cmd", "maven.bat"}},
		{"4", true, []string{"mvn.cmd", "mvn.bat"}},
	}
	for _, c := range cases {
		if got := launcherNames(c.major, c.windows); !slices.Equal(got, c.want) {
			t.Errorf("launcherNames(%s, %t) = %v, want %v", c.major, c.windows, got, c.want)
		}
	}
}

func TestFindLauncher(t *testing.T) {
	// A release unpacks into a directory of its own, with its launchers in bin.
	root := t.TempDir()
	bin := filepath.Join(root, "maven-3.10.1", "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"mvn.bat", "mvn.cmd", "mvn"} {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("launcher\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// A file of the same name outside bin is not a launcher.
	lib := filepath.Join(root, "maven-3.10.1", "lib")
	if err := os.MkdirAll(lib, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(lib, "maven"), []byte("not a launcher\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// The first name that is found wins, in the order of names.
	got, err := findLauncher(root, []string{"mvn.cmd", "mvn.bat", "mvn"})
	if err != nil || got != filepath.Join(bin, "mvn.cmd") {
		t.Fatalf("findLauncher = %q, %v; want %q", got, err, filepath.Join(bin, "mvn.cmd"))
	}
	if _, err := findLauncher(root, []string{"maven"}); err == nil {
		t.Error("findLauncher must fail when no bin directory has the launcher")
	}
}
