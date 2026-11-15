# Development

[中文](zh-CN/development.md) | [English](development.md)

## Layout

```
metadata.lua              plugin name, version and license
hooks/available.lua       vfox search: the releases of Maven 1 to 4, stable first, newest first, then the pre-releases
hooks/pre_install.lua     vfox install: the URL of the archive and its checksum
hooks/env_keys.lua        PATH: the bin directory of the install
hooks/pre_use.lua         vfox use: the installed release that a spec names, the newest in Maven's order
hooks/post_install.lua    after vfox unpacks the archive: nothing to do
hooks/detect.lua          vfox link --detect maven: the Maven homes already on the machine
lib/util.lua              the two sources, their listings, the archives and the checksum files
lib/maven_version.lua     the order of Maven versions, pre-releases included
lib/detect_maven.lua      finding those Maven homes: their names, their launchers and where to look
tests/*_test.lua          offline tests, run by vfox plugin test
tests/e2e/                the end-to-end check, a Go test, and its image; see e2e.md
.devcontainer/            the dev container; see e2e.md
.github/workflows/        lint, test, license, e2e, and the release
opencode.jsonc            lets OpenCode agent sessions in this repository run git push, gh pr create and gh pr comment without asking
Injection.lua             type hints for what vfox injects; never loaded
README*.md, docs/         the documentation, in English and in zh-CN
stylua.toml, .luarc.json  formatting, and the Lua language server
.licenserc.yaml           the license header check
```

vfox loads `metadata.lua`, calls a hook when a command needs it, and puts `PLUGIN` and `RUNTIME` in scope.

## What runs for a command

| You run | Hooks |
| --- | --- |
| `vfox search maven` | `Available`, which reads the listings of dlcdn.apache.org and archive.apache.org |
| `vfox install maven@3.10.1` | `PreInstall` finds the source that lists the release, and returns its URL and the checksum. vfox downloads, checks the checksum and unpacks, then calls `PostInstall` |
| `vfox use maven@3.10.1` | `PreUse`, which finds the installed release that the spec names, then `EnvKeys`, which provides `PATH` |
| `vfox link --detect maven` | `Detect`, which returns the Maven homes already on the machine (`lib/detect_maven.lua`). vfox lists them and links the ones you pick, and `vfox use` then works as it does for an install |

`PreUse` does the matching for `vfox use`. vfox matches a spec on its own too, but it compares only the numbers of versions, so `maven@4` could take 4.0.0-alpha-2 over 4.0.0-alpha-13. The hook picks the newest installed release in Maven's order, and the end-to-end check installs both and checks which one `vfox use maven@4` selects.

The source of an install follows the listing of dlcdn.apache.org, not the checksum files. dlcdn.apache.org redirects the checksum files of some older releases to the archive, while the archive itself is not on dlcdn.apache.org; so a checksum that dlcdn.apache.org answers does not show where the archive is.

## Checks

Run these from the repository root. They are the checks CI runs, and the dev container has the same tools at the same versions.

```bash
stylua --check .                                    # formatting (lint.yml)
lua-language-server --check . --checklevel=Warning  # Lua diagnostics (lint.yml)
vfox plugin test .                                  # offline tests (test.yml)
license-eye header check                            # license headers (license.yml)
```

The Go code of the end-to-end check is checked from `tests/e2e`:

```bash
gofmt -l .        # prints nothing when the formatting is right
go vet ./...
go test -short ./...
```

To fix the formatting, run `stylua .` or `gofmt -w .`. To add missing license headers, run `license-eye header fix`.

In a linked git worktree, `.git` is a file that points at the main repository. A license check in a container that cannot see that repository reports it as a file without a header. Run the check on a clone, as CI does.

## Tests

`vfox plugin test .` runs every `tests/**/*_test.lua` in a VM of its own, so a new file needs no entry anywhere. Each test calls `test.load()` from `vfox.test`, and then calls the hooks through the plugin object that it returns. The `http` function passed to `test.load` answers the plugin's HTTP requests, so the tests need no network:

```lua
local test = require("vfox.test")
local plugin = test.load({
    http = function(request)
        return { status_code = 200, body = "..." }
    end,
})
local result = plugin:PreInstall({ version = "3.10.1" })
```

The end-to-end check (`tests/e2e`) runs the real plugin against Apache's servers; see [e2e.md](e2e.md).

## Releasing

A maintainer publishes from **Actions → Plugin → Run workflow** on the default branch, entering a stable plugin version without the `v` prefix. The shared workflow, [plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action), updates `metadata.lua`, creates the version commit and tag, and publishes the ZIP and manifest in this repository. No local tag or extra release token is needed. Pull requests run checks only; a PR title does not trigger publication.

Pushing a version tag that already matches `PLUGIN.version` publishes too. If publication fails, re-run the failed job to resume it.

The workflow follows the shared `@v1` release tool, and updating the tool does not release this plugin. The shared workflow's documentation has the package contract and the requirements of a first rollout.

## After a release

The documentation marks what is newer than the last release with "Unreleased" ("未发布" in Chinese). Once a release is out, move those entries in [changes.md](changes.md) under the new version, with the date of the release, and take the remarks out, in both languages: `grep -rn -i -e unreleased -e 未发布 docs README*`.

## Known gaps

- Maven 1.1 runs on JDK 8 only, see [versions.md](versions.md#maven-1).
- `vfox link --detect maven` does not find Maven 1, whose files name no version. Link it by hand, see [link.md](link.md).
- On Windows, `--detect` reads the version from the names of the jars only, as there is no launcher it can ask. A Maven whose jar names no version is not found there.
- CI runs the end-to-end check on Linux amd64 and arm64, and on Windows x86_64 and arm64. On Windows arm64, Maven 1.1 runs on an x64 JDK 8 under emulation, see [e2e.md](e2e.md).

## Writing the docs

English pages are in `docs/`, the Chinese ones in `docs/zh-CN/` under the same names, and each page starts with a link to the other language. The README files are `README.md` and `README_CN.md`.
