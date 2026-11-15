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
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"
)

// TestE2E installs Maven through vfox, from the plugin in this repository, and runs it.
// It downloads Maven from Apache, so it is skipped under go test -short, which runs the
// unit tests only.
//
// It needs vfox 1.1.0 on PATH, the default Java runtime for Maven 2 to 4, and
// VFOX_MAVEN_JAVA8_HOME, a JDK 8 with lib/tools.jar, for Maven 1.1: its launcher passes an
// option that JDK 9 and later refuse. VFOX_MAVEN_PLUGIN_DIR names the checkout of the plugin
// and defaults to the repository this package is in. See docs/e2e.md.
//
// Run it from tests/e2e:
//
//	go test -v -run '^TestE2E$' -timeout 40m .
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the end-to-end check downloads Maven from Apache; run it without -short")
	}
	plugin := pluginDirectory(t)
	java8 := requiredEnv(t, "VFOX_MAVEN_JAVA8_HOME")
	binary, err := exec.LookPath("vfox")
	if err != nil {
		t.Fatalf("vfox is not on PATH: %v", err)
	}
	v := vfox{binary: binary, home: tempDir(t)}

	zipPath := filepath.Join(tempDir(t), "maven.zip")
	if err := packPlugin(plugin, zipPath); err != nil {
		t.Fatalf("pack the plugin: %v", err)
	}
	if out, err := v.run("add", "maven", "--source", zipPath); err != nil {
		t.Fatalf("vfox add maven: %v\n%s", err, out)
	}

	out, err := v.run("search", "maven")
	if err != nil {
		t.Fatalf("vfox search maven: %v\n%s", err, out)
	}
	listed := parseListing(out)
	for _, version := range historical {
		if !slices.Contains(listed, version) {
			t.Fatalf("vfox search maven does not list %s, which archive.apache.org has:\n%s", version, out)
		}
	}
	newest4, err := newestOf(listed, "4")
	if err != nil {
		t.Fatal(err)
	}
	newest3, err := newestOf(listed, "3")
	if err != nil {
		t.Fatal(err)
	}

	targets := append([]string{newest4, newest3}, historical...)
	for _, version := range targets {
		t.Run(version, func(t *testing.T) {
			checkRelease(t, v, plugin, version, java8)
		})
	}
}

// checkRelease installs one release and checks three things: that vfox verified its
// checksum, that the launcher the release ships runs and reports the release, and that
// the EnvKeys hook of the plugin puts the release's bin directory on PATH.
func checkRelease(t *testing.T, v vfox, plugin, version, java8 string) {
	spec := "maven@" + version
	out, err := v.run("install", spec)
	if err != nil {
		t.Fatalf("vfox install %s: %v\n%s", spec, err, out)
	}
	if !strings.Contains(out, "Verifying checksum") || strings.Contains(out, "Checksum is not provided") {
		t.Fatalf("vfox install %s did not verify a checksum:\n%s", spec, out)
	}

	dir, err := v.installDir(spec)
	if err != nil {
		t.Fatal(err)
	}
	major := majorOf(version)
	launcher, err := findLauncher(dir, launcherNames(major, runtime.GOOS == "windows"))
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(launcher, "-v")
	want := "Apache Maven " + version
	if major == "1" {
		// Maven 1 has no such line: its banner ends with "v. 1.1".
		cmd.Env = withJava(os.Environ(), java8)
		want = "v. " + version
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s -v: %v\n%s", launcher, err, output)
	}
	if !strings.Contains(string(output), want) {
		t.Fatalf("%s -v does not report %s:\n%s", launcher, version, output)
	}

	keys, err := v.envKeys(plugin, dir)
	if err != nil {
		t.Fatal(err)
	}
	if got, want := filepath.Clean(keys["PATH"]), filepath.Join(dir, "bin"); got != want {
		t.Fatalf("EnvKeys sets PATH to %q, want %q", got, want)
	}
}

// pluginDirectory returns the checkout of the plugin that the check installs.
func pluginDirectory(t *testing.T) string {
	t.Helper()
	dir := os.Getenv("VFOX_MAVEN_PLUGIN_DIR")
	if dir == "" {
		dir = filepath.Join("..", "..")
	}
	abs, err := filepath.Abs(dir)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(abs, "metadata.lua")); err != nil {
		t.Fatalf("%s is not a checkout of the plugin: %v", abs, err)
	}
	return abs
}

// requiredEnv returns the value of an environment variable that the check cannot run without.
func requiredEnv(t *testing.T, name string) string {
	t.Helper()
	value := os.Getenv(name)
	if value == "" {
		t.Fatalf("%s is not set: point it at a JDK 8, see docs/e2e.md", name)
	}
	return value
}

// tempDir returns a new temporary directory that the test removes when it ends. Windows
// keeps a file locked while a process runs, so a directory may stay there; that is logged.
func tempDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "vfox-maven-e2e-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := os.RemoveAll(dir); err != nil {
			t.Logf("could not remove %s: %v", dir, err)
		}
	})
	return dir
}
