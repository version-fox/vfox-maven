# Versions

[中文](zh-CN/versions.md) | [English](versions.md)

`vfox search maven` lists every Maven 2, 3 and 4 release that Apache publishes, newest first. The list is read from two places:

- [dlcdn.apache.org](https://dlcdn.apache.org/maven/), the mirror network that lists the current releases;
- [archive.apache.org](https://archive.apache.org/dist/maven/), which keeps every release, the old ones too.

A release that both have is listed once. Maven 4 pre-releases, such as `4.0.0-rc-7`, are listed as well.

Versions are compared the way Maven's own releases come, not as text: `3.10.1` is newer than `3.9.16`, `4.0.0` is newer than `4.0.0-rc-7`, and `4.0.0-alpha-10` is newer than `4.0.0-alpha-2`.

## Installing a version

A version installs under the name it has in the list:

```bash
vfox install maven@3.10.1
vfox install maven@3.0.5
```

The archive comes from dlcdn.apache.org when that lists the release, and from archive.apache.org otherwise. Both lay out the archives the same way: `maven-<major>/<version>/binaries/apache-maven-<version>-bin.tar.gz`.

## Checksums

Apache publishes a checksum file beside each archive: `.sha512` for most releases, and `.sha1` or `.md5` for the older ones. The plugin reads the strongest file that exists at the source it chose, and gives its digest to vfox. vfox checks the download against it, and the install stops if the two differ.

## Not listed

Maven 1 is not listed. Its one release, 1.1, lays its archives out differently, and it runs as `maven` rather than `mvn`.
