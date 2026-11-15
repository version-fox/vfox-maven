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

func TestWithHome(t *testing.T) {
	env := []string{
		"PATH=/usr/bin",
		"HOME=/root",
		"Userprofile=C:\\old",
		"VFOX_HOME=/cache",
		"__VFOX_PID=42",
		"__VFOX_SHELL=bash",
		"JAVA_HOME=/jdk",
	}
	got := withHome(env, "/tmp/e2e")
	want := []string{"PATH=/usr/bin", "JAVA_HOME=/jdk", "HOME=/tmp/e2e", "USERPROFILE=/tmp/e2e"}
	if !slices.Equal(got, want) {
		t.Fatalf("withHome = %v, want %v", got, want)
	}
}

func TestWithJava(t *testing.T) {
	env := []string{"Path=/usr/bin", "JAVA_HOME=/jdk21", "FOO=bar"}
	got := withJava(env, "/opt/jdk8")
	want := []string{
		"FOO=bar",
		"JAVA_HOME=/opt/jdk8",
		"PATH=" + filepath.Join("/opt/jdk8", "bin") + string(os.PathListSeparator) + "/usr/bin",
	}
	if !slices.Equal(got, want) {
		t.Fatalf("withJava = %v, want %v", got, want)
	}
}

func TestParseEnvKeys(t *testing.T) {
	// vfox may print a line before the JSON.
	output := "a warning\n[{\"key\":\"PATH\",\"value\":\"/a/maven-3.10.1/bin\"}]\n"
	got, err := parseEnvKeys(output)
	if err != nil || got["PATH"] != "/a/maven-3.10.1/bin" {
		t.Fatalf("parseEnvKeys = %v, %v", got, err)
	}
	if _, err := parseEnvKeys("no JSON here"); err == nil {
		t.Error("parseEnvKeys must fail on output with no JSON array")
	}
}
