# Using Mavens that are already on the machine

[中文](zh-CN/link.md) | [English](link.md)

If a Maven is already on the machine — from the system package manager, Homebrew, Scoop or Chocolatey, SDKMAN, asdf or mise, or unpacked by hand — `vfox link --detect maven` adopts it instead of downloading another copy. It needs vfox 1.1.0 or later (`vfox --version`).

```bash
vfox link --detect maven
```

vfox lists what the plugin found and links what you pick. `vfox link --detect -y maven` links everything without asking. Afterwards `vfox use maven@...` works as usual: `vfox list maven` marks linked versions `(linked → <path>)`, and `vfox uninstall` removes only the link, leaving the Maven where it is.

## What it finds

- `M2_HOME` and `MAVEN_HOME`, when they name a Maven home
- The system package, `/usr/share/maven` (Debian, Ubuntu and Fedora), and the directories in `/opt` and `/usr/local`
- Homebrew kegs (`/opt/homebrew/opt`, `/usr/local/opt` and Linuxbrew)
- SDKMAN, asdf and mise
- On Windows, Scoop apps (`scoop\apps\maven`), Chocolatey packages (`C:\ProgramData\chocolatey\lib\maven`) and the directories in `Program Files`

vfox's own installs are never found.

## Version names

A found Maven is named the way `vfox install` names it: by its version, such as `3.9.9` or `4.0.0-rc-7`. The version comes from the names of the files in the Maven's `lib` directory: `maven-core-<version>.jar` for Maven 3 and 4, and `maven-<version>-uber.jar` for Maven 2. Debian and Ubuntu name their core jar `maven-core-3.x.jar`, so on Linux the plugin asks `mvn -v` for the version. On Windows, a Maven whose jar names no version is not found.

Maven 1 names no version in its files, so `--detect` does not find it. Link it by hand.

## Linking by hand

Where `--detect` does not look, point at the Maven home itself, the directory that holds `bin`:

```bash
vfox link maven@1.1 /opt/maven-1.1
vfox use maven@1.1
```

Maven 1.1 runs on JDK 8 only, see [versions.md](versions.md#maven-1).
