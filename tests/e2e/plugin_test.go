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
	"archive/zip"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestPackPlugin(t *testing.T) {
	plugin := t.TempDir()
	files := map[string]string{
		"metadata.lua":        "PLUGIN = {}\n",
		"hooks/available.lua": "-- a hook\n",
		"lib/util.lua":        "return {}\n",
		"README.md":           "not part of the plugin\n",
	}
	for name, content := range files {
		path := filepath.Join(plugin, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	zipPath := filepath.Join(t.TempDir(), "maven.zip")
	if err := packPlugin(plugin, zipPath); err != nil {
		t.Fatal(err)
	}
	reader, err := zip.OpenReader(zipPath)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()

	var names []string
	for _, entry := range reader.File {
		names = append(names, entry.Name)
	}
	want := []string{"metadata.lua", "hooks/available.lua", "lib/util.lua"}
	if !slices.Equal(names, want) {
		t.Fatalf("zip entries = %v, want %v", names, want)
	}
}
