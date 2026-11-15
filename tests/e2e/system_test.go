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
	"runtime"
	"testing"
)

func TestCopyTree(t *testing.T) {
	src := t.TempDir()
	if err := os.MkdirAll(filepath.Join(src, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "bin", "mvn"), []byte("launcher\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "README"), []byte("maven\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("bin", filepath.Join(src, "current")); err != nil {
		t.Skipf("symbolic links are not available: %v", err)
	}

	dst := filepath.Join(t.TempDir(), "copy")
	if err := copyTree(src, dst); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"bin/mvn", "README"} {
		want, err := os.ReadFile(filepath.Join(src, name))
		if err != nil {
			t.Fatal(err)
		}
		got, err := os.ReadFile(filepath.Join(dst, name))
		if err != nil {
			t.Fatal(err)
		}
		if string(got) != string(want) {
			t.Errorf("%s: copied %q, want %q", name, got, want)
		}
	}
	if runtime.GOOS != "windows" {
		info, err := os.Stat(filepath.Join(dst, "bin", "mvn"))
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode().Perm()&0o100 == 0 {
			t.Errorf("bin/mvn lost its executable bit: %v", info.Mode())
		}
		link, err := os.Readlink(filepath.Join(dst, "current"))
		if err != nil || link != "bin" {
			t.Errorf("current is a link to %q (%v), want bin", link, err)
		}
	}
}

func TestMavenHomeOf(t *testing.T) {
	install := t.TempDir()
	if got := mavenHomeOf(install, "3.0.5"); got != install {
		t.Errorf("without maven-3.0.5 the install is the home, got %s", got)
	}
	home := filepath.Join(install, "maven-3.0.5")
	if err := os.MkdirAll(filepath.Join(home, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if got := mavenHomeOf(install, "3.0.5"); got != home {
		t.Errorf("the home is maven-3.0.5 under the install, got %s", got)
	}
}
