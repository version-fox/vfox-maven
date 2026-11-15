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
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

// packPlugin writes the files that vfox loads from a checkout of the plugin to a zip
// file, in the layout that vfox add --source reads: metadata.lua, then the hooks and
// lib directories. The entry names use forward slashes on every platform.
func packPlugin(plugin, zipPath string) (err error) {
	out, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := out.Close(); err == nil {
			err = closeErr
		}
	}()

	names := []string{"metadata.lua"}
	for _, dir := range []string{"hooks", "lib"} {
		err := filepath.WalkDir(filepath.Join(plugin, dir), func(path string, entry fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if entry.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(plugin, path)
			if err != nil {
				return err
			}
			names = append(names, filepath.ToSlash(rel))
			return nil
		})
		if err != nil {
			return err
		}
	}

	zw := zip.NewWriter(out)
	for _, name := range names {
		if err := addPluginFile(zw, plugin, name); err != nil {
			return err
		}
	}
	return zw.Close()
}

// addPluginFile copies one file of the plugin into the zip under the same name.
func addPluginFile(zw *zip.Writer, plugin, name string) error {
	in, err := os.Open(filepath.Join(plugin, filepath.FromSlash(name)))
	if err != nil {
		return err
	}
	defer in.Close()

	w, err := zw.Create(name)
	if err != nil {
		return err
	}
	_, err = io.Copy(w, in)
	return err
}
