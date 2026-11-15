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
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// vfox runs one vfox binary with a home directory of its own. vfox keeps its plugins,
// SDKs and global selections under the home directory: HOME on Linux and macOS,
// USERPROFILE on Windows. Both are set for the child process.
type vfox struct {
	binary string
	home   string
}

// run runs vfox with args and returns what it printed to stdout and stderr.
func (v vfox) run(args ...string) (string, error) {
	return v.runWith(nil, args...)
}

// runWith runs vfox with args, and with the variables of extra added to its environment, such as
// M2_HOME.
func (v vfox) runWith(extra []string, args ...string) (string, error) {
	cmd := exec.Command(v.binary, args...)
	cmd.Env = append(withHome(os.Environ(), v.home), extra...)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

// installDir returns the directory that vfox installed a release in. It asks vfox info,
// which needs no shell hook, where vfox use does.
func (v vfox) installDir(spec string) (string, error) {
	output, err := v.run("info", spec)
	if err != nil {
		return "", fmt.Errorf("vfox info %s: %w\n%s", spec, err, output)
	}
	lines := strings.Split(strings.TrimSpace(output), "\n")
	dir := strings.TrimSpace(lines[len(lines)-1])
	if dir == "" {
		return "", fmt.Errorf("vfox info %s printed no directory:\n%s", spec, output)
	}
	return dir, nil
}

// envKeys runs the EnvKeys hook of the plugin in plugin for an install directory, and
// returns the variables that the hook sets. vfox plugin run runs the hook itself, so the
// check does not depend on a shell hook.
func (v vfox) envKeys(plugin, installDir string) (map[string]string, error) {
	input, err := json.Marshal(map[string]string{"path": installDir})
	if err != nil {
		return nil, err
	}
	output, err := v.run("plugin", "run", plugin, "EnvKeys", "--input", string(input), "--json")
	if err != nil {
		return nil, fmt.Errorf("vfox plugin run EnvKeys: %w\n%s", err, output)
	}
	return parseEnvKeys(output)
}

// parseEnvKeys reads the variables from the output of vfox plugin run EnvKeys --json, which
// is a JSON array of {"key": ..., "value": ...}. vfox may print other lines around it.
func parseEnvKeys(output string) (map[string]string, error) {
	start := strings.Index(output, "[")
	end := strings.LastIndex(output, "]")
	if start < 0 || end < start {
		return nil, fmt.Errorf("vfox plugin run printed no JSON array:\n%s", output)
	}
	var entries []struct {
		Key   string `json:"key"`
		Value string `json:"value"`
	}
	if err := json.Unmarshal([]byte(output[start:end+1]), &entries); err != nil {
		return nil, fmt.Errorf("vfox plugin run: %w\n%s", err, output)
	}
	keys := make(map[string]string, len(entries))
	for _, entry := range entries {
		keys[entry.Key] = entry.Value
	}
	return keys, nil
}

// withHome returns env with the home directories replaced by home, and with the variables of
// a vfox session removed. So everything vfox writes lands under home, and a shell that the
// check starts does not inherit the session of the shell that started the check.
func withHome(env []string, home string) []string {
	kept := make([]string, 0, len(env)+2)
	for _, entry := range env {
		name, _, _ := strings.Cut(entry, "=")
		if isVfoxVariable(name) {
			continue
		}
		kept = append(kept, entry)
	}
	return append(kept, "HOME="+home, "USERPROFILE="+home)
}

// isVfoxVariable reports whether name decides where vfox keeps its files, or belongs to a shell
// that has vfox activated. Variable names are compared without regard to case, as Windows does.
func isVfoxVariable(name string) bool {
	upper := strings.ToUpper(name)
	if strings.HasPrefix(upper, "__VFOX_") {
		return true
	}
	return upper == "HOME" || upper == "USERPROFILE" || upper == "VFOX_HOME"
}

// withJava returns env with JAVA_HOME set to java, and the bin directory of java first on PATH.
func withJava(env []string, java string) []string {
	kept := make([]string, 0, len(env)+2)
	path := ""
	for _, entry := range env {
		name, value, _ := strings.Cut(entry, "=")
		switch {
		case strings.EqualFold(name, "JAVA_HOME"):
			continue
		case strings.EqualFold(name, "PATH"):
			path = value
			continue
		}
		kept = append(kept, entry)
	}
	bin := filepath.Join(java, "bin")
	return append(kept, "JAVA_HOME="+java, "PATH="+bin+string(os.PathListSeparator)+path)
}
