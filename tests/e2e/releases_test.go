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

func TestLauncherCommand(t *testing.T) {
	for major, want := range map[string]string{"1": "maven", "2": "mvn", "3": "mvn", "4": "mvn"} {
		if got := launcherCommand(major); got != want {
			t.Errorf("launcherCommand(%s) = %s, want %s", major, got, want)
		}
	}
}
