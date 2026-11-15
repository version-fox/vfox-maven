# 变更记录

[中文](changes.md) | [English](../changes.md)

每个版本改了什么，从用户的角度来看。GitHub 的发布页列出了对应的拉取请求。

## 未发布

- 插件可以安装 Maven 1 到 4，包括只有 archive.apache.org 保存的旧版本。`vfox search maven` 列出 dlcdn.apache.org 或 archive.apache.org 上的每个版本，每个只列一次，`vfox install` 从列出它的那个源下载。Maven 2.0.11 安装的是它的 zip，因为它的 tar.gz 解不开。见 [versions.md](versions.md)。
- `vfox use maven@4` 选中写法所指的、已安装的版本。装了 4.0.0-alpha-2 和 4.0.0-alpha-13 时，它选中 4.0.0-alpha-13，以前选中的是 4.0.0-alpha-2。写法按整段匹配：`3.1` 不指 `3.10.1`。
- 版本按 Maven 自己的发布顺序比较：`3.10.1` 比 `3.9.16` 新，`4.0.0` 比 `4.0.0-rc-7` 新。
- `vfox link --detect maven` 会采用本机上已有的 Maven：`M2_HOME` 和 `MAVEN_HOME`、系统包、Homebrew、SDKMAN、asdf、mise、Scoop 和 Chocolatey。见 [link.md](link.md)。
- 列表读不到时，停止查找并报告 HTTP 状态，而不是报内部的 Lua 错误。
- `vfox search maven` 先列稳定版，再列预览版，各自从新到旧。所以 `vfox install maven@latest` 安装最新的稳定版，而不是 `4.0.0-rc-7` 这样的预览版。预览版仍然列出。见 [versions.md](versions.md)。
