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
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// TestE2E installs Maven through vfox, from the plugin in this repository, and runs it. It
// downloads Maven from Apache, so it is skipped under go test -short, which runs the unit
// tests only.
//
// It needs vfox 1.1.0 on PATH, the default Java runtime for Maven 2 to 4, and
// VFOX_MAVEN_JAVA8_HOME, a JDK 8 with lib/tools.jar, for Maven 1.1: its launcher passes an
// option that JDK 9 and later refuse. VFOX_MAVEN_PLUGIN_DIR names the checkout of the plugin
// and defaults to the repository this package is in. Scenarios run in bash, or in PowerShell 7
// on Windows; see use.go and docs/e2e.md.
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
			checkRelease(t, v, plugin, java8, version)
		})
	}
	t.Run("session overrides global", func(t *testing.T) {
		checkSessionScope(t, v.home, archivedMaven3, newest3)
	})
	t.Run("project scope", func(t *testing.T) {
		checkProjectScope(t, v.home, newest3, archivedMaven3)
	})
	t.Run("major version spec", func(t *testing.T) {
		checkMajorSpec(t, v.home, "3", newest3)
	})
	t.Run("prerelease order", func(t *testing.T) {
		checkPrereleaseOrder(t, binary, zipPath)
	})
	t.Run("system maven linked and used", func(t *testing.T) {
		install, err := v.installDir("maven@" + archivedMaven3)
		if err != nil {
			t.Fatal(err)
		}
		checkSystemMaven(t, binary, zipPath, mavenHomeOf(install, archivedMaven3))
	})
}

// checkRelease installs one release, and checks three things: that vfox verified its checksum,
// that vfox use makes the release the global version and the Maven command runs it, and that
// the EnvKeys hook of the plugin puts the bin directory of the release on PATH.
func checkRelease(t *testing.T, v vfox, plugin, java8, version string) {
	spec := "maven@" + version
	out, err := v.run("install", spec)
	if err != nil {
		t.Fatalf("vfox install %s: %v\n%s", spec, err, out)
	}
	if !strings.Contains(out, "Verifying checksum") || strings.Contains(out, "Checksum is not provided") {
		t.Fatalf("vfox install %s did not verify a checksum:\n%s", spec, out)
	}

	major := majorOf(version)
	s := scenario{
		home:     v.home,
		dir:      v.home,
		launcher: launcherCommand(major),
		steps:    []step{{use: []string{"--global", spec}}, {report: true}},
	}
	if major == "1" {
		s.java = java8
	}
	checkReport(t, runOne(t, s), version, globalDir(v.home))

	dir, err := v.installDir(spec)
	if err != nil {
		t.Fatal(err)
	}
	keys, err := v.envKeys(plugin, dir)
	if err != nil {
		t.Fatal(err)
	}
	if got, want := filepath.Clean(keys["PATH"]), filepath.Join(dir, "bin"); got != want {
		t.Fatalf("EnvKeys sets PATH to %q, want %q", got, want)
	}
}

// checkSessionScope checks that a release selected for the session wins over the global
// selection, and that the session ends with its shell: the next shell sees the global one.
func checkSessionScope(t *testing.T, home, global, session string) {
	t.Helper()
	selected := runOne(t, scenario{
		home:     home,
		dir:      home,
		launcher: "mvn",
		steps: []step{
			{use: []string{"--global", "maven@" + global}},
			{use: []string{"maven@" + session}},
			{report: true},
		},
	})
	checkReport(t, selected, session, home)

	after := runOne(t, scenario{
		home:     home,
		dir:      home,
		launcher: "mvn",
		steps:    []step{{report: true}},
	})
	checkReport(t, after, global, globalDir(home))
}

// checkProjectScope checks that vfox use --project selects a release for a project directory,
// in the project's .vfox.toml, and that the global selection still applies outside it.
func checkProjectScope(t *testing.T, home, version, global string) {
	t.Helper()
	project := tempDir(t)
	inside := runOne(t, scenario{
		home:     home,
		dir:      project,
		launcher: "mvn",
		steps:    []step{{use: []string{"--project", "maven@" + version}}, {report: true}},
	})
	checkReport(t, inside, version, project)

	data, err := os.ReadFile(filepath.Join(project, ".vfox.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if want := fmt.Sprintf("maven = %q", version); !strings.Contains(string(data), want) {
		t.Fatalf(".vfox.toml does not contain %q:\n%s", want, data)
	}

	outside := runOne(t, scenario{
		home:     home,
		dir:      home,
		launcher: "mvn",
		steps:    []step{{report: true}},
	})
	checkReport(t, outside, global, globalDir(home))
}

// checkMajorSpec checks that vfox use with a major version alone selects the newest installed
// release of that major version.
func checkMajorSpec(t *testing.T, home, major, version string) {
	t.Helper()
	selected := runOne(t, scenario{
		home:     home,
		dir:      home,
		launcher: launcherCommand(major),
		steps:    []step{{use: []string{"--global", "maven@" + major}}, {report: true}},
	})
	checkReport(t, selected, version, globalDir(home))
}

// checkPrereleaseOrder checks that vfox use selects the newest pre-release that a spec names, in
// Maven's order. vfox itself compares only the numbers of versions, so it may take 4.0.0-alpha-2
// for 4.0.0-alpha-13; the plugin's PreUse decides instead. The check runs in a home of its own,
// so no other release of Maven 4 is installed there.
func checkPrereleaseOrder(t *testing.T, binary, zipPath string) {
	t.Helper()
	v := vfox{binary: binary, home: tempDir(t)}
	if out, err := v.run("add", "maven", "--source", zipPath); err != nil {
		t.Fatalf("vfox add maven: %v\n%s", err, out)
	}
	for _, version := range []string{"4.0.0-alpha-2", "4.0.0-alpha-13"} {
		if out, err := v.run("install", "maven@"+version); err != nil {
			t.Fatalf("vfox install maven@%s: %v\n%s", version, err, out)
		}
	}
	for _, spec := range []string{"4", "4.0"} {
		selected := runOne(t, scenario{
			home:     v.home,
			dir:      v.home,
			launcher: "mvn",
			steps:    []step{{use: []string{"--global", "maven@" + spec}}, {report: true}},
		})
		checkReport(t, selected, "4.0.0-alpha-13", globalDir(v.home))
	}
}

// checkReport checks that vfox reports version as current, that the Maven command resolves to
// a launcher inside dir, and that the command runs that version.
func checkReport(t *testing.T, r report, version, dir string) {
	t.Helper()
	if r.current != version {
		t.Fatalf("vfox current reports %q, want %s", r.current, version)
	}
	if !underDir(r.launcher, dir) {
		t.Fatalf("the Maven command resolves to %s, want a path under %s", r.launcher, dir)
	}
	if !strings.Contains(r.output, banner(version)) {
		t.Fatalf("the Maven command does not report %s:\n%s", version, r.output)
	}
}

// banner returns the line that the Maven command prints to report a version. Maven 1 has no
// such line: its banner ends with "v. 1.1".
func banner(version string) string {
	if majorOf(version) == "1" {
		return "v. " + version
	}
	return "Apache Maven " + version
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

// tempDir returns a new temporary directory that the test removes when it ends. Windows keeps
// a file locked while a process runs, so a directory may stay there; that is logged.
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
