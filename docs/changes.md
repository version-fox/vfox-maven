# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list the pull requests.

## 0.1.3 (2026-11-15)

- The plugin installs Maven 1 to 4, including the releases that only archive.apache.org keeps. `vfox search maven` lists every release that dlcdn.apache.org or archive.apache.org has, each once, and `vfox install` takes each one from the source that lists it. Maven 2.0.11 installs from its zip, as its tar.gz does not unpack. See [versions.md](versions.md).
- `vfox use maven@4` selects the installed release that the spec names. With 4.0.0-alpha-2 and 4.0.0-alpha-13 installed, it selects 4.0.0-alpha-13, where it used to select 4.0.0-alpha-2. A spec names whole parts: `3.1` does not name `3.10.1`.
- Versions are ordered the way Maven orders its releases: `3.10.1` is newer than `3.9.16`, and `4.0.0` is newer than `4.0.0-rc-7`.
- `vfox link --detect maven` adopts the Mavens that are already on the machine: `M2_HOME` and `MAVEN_HOME`, the system package, Homebrew, SDKMAN, asdf, mise, Scoop and Chocolatey. See [link.md](link.md).
- A listing that cannot be read stops the search with its HTTP status, not with an internal Lua error.
- `vfox search maven` lists the stable releases first, then the pre-releases, each newest first. So `vfox install maven@latest` installs the newest stable release, not a pre-release such as `4.0.0-rc-7`. Pre-releases stay listed. See [versions.md](versions.md).
