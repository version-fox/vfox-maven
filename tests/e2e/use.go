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
	"regexp"
	"runtime"
	"strings"
	"testing"
)

// vfox use takes effect only in a shell that has vfox activated, as a user's shell is: on
// Linux and macOS it refuses to run in any other. The check therefore runs its scenarios in
// such a shell: bash on Linux and macOS, and PowerShell 7 (pwsh) on Windows. A script does not
// run the prompt hook that applies vfox env, so the script applies it after each use. The
// variable VFOX_MAVEN_SHELL, bash or pwsh, overrides the choice.

// reportMarker starts the lines of a report step, which tell the report apart from the output
// of vfox and of the Maven command.
const reportMarker = "VFOX_E2E_REPORT"

// ansiCode matches the colour codes that vfox prints.
var ansiCode = regexp.MustCompile(`\x1b\[[0-9;]*m`)

// step is one command of a scenario.
type step struct {
	use    []string // the arguments of vfox use, or nil for a report
	report bool     // report what is selected, and what the Maven command runs
}

// scenario is a sequence of steps that one shell runs.
type scenario struct {
	home     string // HOME and USERPROFILE of the shell, where vfox keeps its files
	dir      string // the directory the shell starts in, which is the project for --project
	launcher string // the Maven command to run: mvn, or maven for Maven 1
	java     string // JAVA_HOME for the Maven command, or "" for the default JDK
	steps    []step
}

// report is what a report step printed.
type report struct {
	current  string // the version that vfox current reports
	launcher string // the path that the shell resolves the Maven command to
	output   string // what the Maven command printed
}

// shellName returns the shell that runs the scenarios.
func shellName() string {
	if name := os.Getenv("VFOX_MAVEN_SHELL"); name != "" {
		return name
	}
	if runtime.GOOS == "windows" {
		return "pwsh"
	}
	return "bash"
}

// run runs the scenario in a shell and returns the report of each report step, in order.
func (s scenario) run(t *testing.T) []report {
	t.Helper()
	var file, script string
	var cmd *exec.Cmd
	shell := shellName()
	switch shell {
	case "bash":
		file, script = "scenario.sh", bashScript(s.steps)
	case "pwsh":
		file, script = "scenario.ps1", pwshScript(s.steps)
	default:
		t.Fatalf("VFOX_MAVEN_SHELL is %q, want bash or pwsh", shell)
	}
	path := filepath.Join(tempDir(t), file)
	if err := os.WriteFile(path, []byte(script), 0o644); err != nil {
		t.Fatal(err)
	}
	if shell == "pwsh" {
		cmd = exec.Command("pwsh", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", path)
	} else {
		cmd = exec.Command("bash", path)
	}
	cmd.Dir = s.dir
	cmd.Env = append(withHome(os.Environ(), s.home), "VFOX_E2E_LAUNCHER="+s.launcher)
	if s.java != "" {
		cmd.Env = withJava(cmd.Env, s.java)
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s scenario: %v\n%s", shell, err, output)
	}
	reports, err := parseReports(string(output))
	if err != nil {
		t.Fatalf("%s scenario: %v\n%s", shell, err, output)
	}
	return reports
}

// runOne runs a scenario that has one report step, and returns its report.
func runOne(t *testing.T, s scenario) report {
	t.Helper()
	reports := s.run(t)
	if len(reports) != 1 {
		t.Fatalf("scenario has %d reports, want 1", len(reports))
	}
	return reports[0]
}

// bashScript returns the script that runs steps in bash, with vfox activated.
func bashScript(steps []step) string {
	var b strings.Builder
	b.WriteString(`set -o errexit -o nounset -o pipefail
eval "$(vfox activate bash)"
vfox_use() {
    vfox use "$@"
    eval "$(vfox env -s bash)"
}
vfox_report() {
    echo ` + reportMarker + `
    echo "CURRENT $(vfox current maven | sed 's/\x1b\[[0-9;]*m//g')"
    echo "LAUNCHER $(command -v "$VFOX_E2E_LAUNCHER")"
    "$VFOX_E2E_LAUNCHER" -v
}
`)
	for _, s := range steps {
		if s.report {
			b.WriteString("vfox_report\n")
			continue
		}
		b.WriteString("vfox_use")
		for _, arg := range s.use {
			b.WriteString(" " + shellQuote(arg))
		}
		b.WriteString("\n")
	}
	return b.String()
}

// pwshScript returns the script that runs steps in PowerShell, with vfox activated.
func pwshScript(steps []step) string {
	var b strings.Builder
	b.WriteString(`$ErrorActionPreference = 'Stop'
Invoke-Expression ((vfox activate pwsh) | Out-String)
function Use-Vfox {
    vfox use @args
    vfox env -s pwsh | Out-String | Invoke-Expression
}
function Show-Report {
    '` + reportMarker + `'
    'CURRENT ' + ((vfox current maven) | Out-String).Trim()
    'LAUNCHER ' + (Get-Command $env:VFOX_E2E_LAUNCHER).Source
    & $env:VFOX_E2E_LAUNCHER -v
    if ($LASTEXITCODE -ne 0) { throw "$env:VFOX_E2E_LAUNCHER -v exited with $LASTEXITCODE" }
}
`)
	for _, s := range steps {
		if s.report {
			b.WriteString("Show-Report\n")
			continue
		}
		b.WriteString("Use-Vfox")
		for _, arg := range s.use {
			b.WriteString(" " + pwshQuote(arg))
		}
		b.WriteString("\n")
	}
	return b.String()
}

// shellQuote quotes a word for bash.
func shellQuote(word string) string {
	return "'" + strings.ReplaceAll(word, "'", `'\''`) + "'"
}

// pwshQuote quotes a word for PowerShell.
func pwshQuote(word string) string {
	return "'" + strings.ReplaceAll(word, "'", "''") + "'"
}

// parseReports returns the reports of the output of a scenario. A report is the marker, then
// the current version, then the path of the Maven command, then what the command printed.
func parseReports(output string) ([]report, error) {
	var reports []report
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimRight(ansiCode.ReplaceAllString(line, ""), "\r")
		switch {
		case line == reportMarker:
			reports = append(reports, report{})
		case len(reports) == 0:
			// The output of vfox before the first report.
		case strings.HasPrefix(line, "CURRENT "):
			current := strings.TrimPrefix(strings.TrimSpace(strings.TrimPrefix(line, "CURRENT ")), "->")
			reports[len(reports)-1].current = strings.TrimSpace(current)
		case strings.HasPrefix(line, "LAUNCHER "):
			reports[len(reports)-1].launcher = strings.TrimSpace(strings.TrimPrefix(line, "LAUNCHER "))
		default:
			last := &reports[len(reports)-1]
			last.output += line + "\n"
		}
	}
	if len(reports) == 0 {
		return nil, fmt.Errorf("the output has no report")
	}
	for i, r := range reports {
		if r.current == "" || r.launcher == "" {
			return nil, fmt.Errorf("report %d has no current version or no launcher", i+1)
		}
		reports[i].output = strings.TrimRight(r.output, "\n")
	}
	return reports, nil
}

// globalDir returns the directory that the global selection of Maven is linked to.
func globalDir(home string) string {
	return filepath.Join(home, ".vfox", "sdks", "maven")
}

// underDir reports whether path is inside dir. Windows paths are compared without regard to
// case.
func underDir(path, dir string) bool {
	path, dir = filepath.Clean(path), filepath.Clean(dir)
	if runtime.GOOS == "windows" {
		path, dir = strings.ToLower(path), strings.ToLower(dir)
	}
	return strings.HasPrefix(path, dir+string(filepath.Separator))
}
