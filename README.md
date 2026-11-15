# Introduction

[中文](README_CN.md) | [English](README.md)

vfox-maven is a plugin for [vfox](https://vfox.lhan.me/). It installs [Apache Maven](https://maven.apache.org/): the Maven 1, 2, 3 and 4 releases that Apache publishes on [dlcdn.apache.org](https://dlcdn.apache.org/maven/) and [archive.apache.org](https://archive.apache.org/dist/maven/), the old ones included.

# Install

After installing vfox, run the following command to add the plugin:

```bash
vfox add maven
```

Maven runs on a Java runtime, which this plugin does not install. Put a JDK on `PATH` or set `JAVA_HOME`. The [vfox-java](https://github.com/version-fox/vfox-java) plugin installs one. Maven 1.1 runs on JDK 8 only.

# Usage

```bash
vfox search maven                # the releases the plugin lists
vfox install maven@3.10.1        # install one; its checksum is verified
vfox use --global maven@3.10.1   # make it the global version
vfox link --detect maven         # adopt a Maven that is already on this machine
mvn --version
```

# Documentation

- [Versions](docs/versions.md): the versions listed, where they come from, and how they are checked
- [Already installed Mavens](docs/link.md): adopting the Mavens on the machine with `vfox link --detect maven`
- [Changes](docs/changes.md): what each release changed
- [Development](docs/development.md): the layout, the tests, the checks, and releasing
- [End-to-end check and dev container](docs/e2e.md)

The Chinese documents are [README_CN.md](README_CN.md) and [docs/zh-CN/](docs/zh-CN/).
