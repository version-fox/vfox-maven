# 使用本机已有的 Maven

[中文](link.md) | [English](../link.md)

如果本机已经有 Maven——系统包管理器、Homebrew、Scoop 或 Chocolatey、SDKMAN、asdf 或 mise 装的，或者手动解压的——`vfox link --detect maven` 会直接采用它，而不用再下载一份。需要 vfox 1.1.0 或更高版本（`vfox --version` 查看）。

```bash
vfox link --detect maven
```

vfox 会列出插件找到的 Maven，选中哪个就链接哪个；`vfox link --detect -y maven` 则全部链接，不再逐个确认。之后 `vfox use maven@...` 和往常一样用：`vfox list maven` 会把链接进来的版本标成 `(linked → <路径>)`，`vfox uninstall` 只删除这个链接，不动原来位置的 Maven。

## 会找什么

- `M2_HOME` 和 `MAVEN_HOME`，如果它们指向一个 Maven 目录
- 系统包，即 `/usr/share/maven`（Debian、Ubuntu 和 Fedora），以及 `/opt` 和 `/usr/local` 里的目录
- Homebrew 的 keg（`/opt/homebrew/opt`、`/usr/local/opt` 和 Linuxbrew）
- SDKMAN、asdf 和 mise
- Windows 上，Scoop 的应用（`scoop\apps\maven`）、Chocolatey 的包（`C:\ProgramData\chocolatey\lib\maven`），以及 `Program Files` 里的目录

vfox 自己装的版本永远不会被找到。

## 版本的名字

找到的 Maven 按 `vfox install` 命名的方式取名：就是它的版本号，比如 `3.9.9` 或 `4.0.0-rc-7`。版本号从 Maven 的 `lib` 目录里的文件名读出：Maven 3 和 4 是 `maven-core-<版本>.jar`，Maven 2 是 `maven-<版本>-uber.jar`。Debian 和 Ubuntu 把核心 jar 命名为 `maven-core-3.x.jar`，所以在 Linux 上插件会运行 `mvn -v` 来取版本号。在 Windows 上，jar 的名字里没有版本号的 Maven 找不到。

Maven 1 的文件里没有版本号，所以 `--detect` 找不到它，需要手动链接。

## 手动链接

`--detect` 找不到的地方，直接指向 Maven 目录本身，也就是包含 `bin` 的那一层：

```bash
vfox link maven@1.1 /opt/maven-1.1
vfox use maven@1.1
```

Maven 1.1 只能在 JDK 8 上运行，见 [versions.md](versions.md#maven-1)。
