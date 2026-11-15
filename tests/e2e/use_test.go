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
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestShellQuoting(t *testing.T) {
	if got := shellQuote("it's"); got != `'it'\''s'` {
		t.Errorf("shellQuote = %s", got)
	}
	if got := pwshQuote("it's"); got != "'it''s'" {
		t.Errorf("pwshQuote = %s", got)
	}
}

func TestBashScript(t *testing.T) {
	script := bashScript([]step{{use: []string{"--global", "maven@3.10.1"}}, {report: true}})
	for _, want := range []string{
		`eval "$(vfox activate bash)"`,
		`eval "$(vfox env -s bash)"`,
		"vfox_use '--global' 'maven@3.10.1'\n",
		"vfox_report\n",
	} {
		if !strings.Contains(script, want) {
			t.Errorf("bash script does not contain %q:\n%s", want, script)
		}
	}
}

func TestPwshScript(t *testing.T) {
	script := pwshScript([]step{{use: []string{"maven@3"}}, {report: true}})
	for _, want := range []string{
		"Invoke-Expression ((vfox activate pwsh) | Out-String)",
		"vfox env -s pwsh | Out-String | Invoke-Expression",
		"Use-Vfox 'maven@3'\n",
		"Show-Report\n",
	} {
		if !strings.Contains(script, want) {
			t.Errorf("pwsh script does not contain %q:\n%s", want, script)
		}
	}
}

func TestParseReports(t *testing.T) {
	output := "Now using maven@3.0.5.\n" +
		"VFOX_E2E_REPORT\n" +
		"CURRENT -> \x1b[92m3.10.1\x1b[0m\n" +
		"LAUNCHER /home/x/.vfox/tmp/s1/maven/bin/mvn\n" +
		"Apache Maven 3.10.1 (3afd8084)\n" +
		"VFOX_E2E_REPORT\r\n" +
		"CURRENT -> 3.0.5\r\n" +
		"LAUNCHER /home/x/.vfox/sdks/maven/bin/mvn\r\n" +
		"Apache Maven 3.0.5 (r01de147)\r\n"
	reports, err := parseReports(output)
	if err != nil {
		t.Fatal(err)
	}
	want := []report{
		{current: "3.10.1", launcher: "/home/x/.vfox/tmp/s1/maven/bin/mvn", output: "Apache Maven 3.10.1 (3afd8084)"},
		{current: "3.0.5", launcher: "/home/x/.vfox/sdks/maven/bin/mvn", output: "Apache Maven 3.0.5 (r01de147)"},
	}
	if !slices.Equal(reports, want) {
		t.Fatalf("parseReports = %+v, want %+v", reports, want)
	}
	if _, err := parseReports("no report here\n"); err == nil {
		t.Error("parseReports must fail on output with no report")
	}
}

func TestUnderDir(t *testing.T) {
	dir := filepath.Join("a", "b")
	for path, want := range map[string]bool{
		filepath.Join("a", "b", "c", "mvn"): true,
		filepath.Join("a", "bc", "mvn"):     false,
		filepath.Join("a", "mvn"):           false,
	} {
		if got := underDir(path, dir); got != want {
			t.Errorf("underDir(%s, %s) = %t, want %t", path, dir, got, want)
		}
	}
}
