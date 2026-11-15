# 版本

[中文](versions.md) | [English](../versions.md)

`vfox search maven` 列出 Apache 发布的每个 Maven 2、3 和 4 版本，最新的在前。列表来自两个地方：

- [dlcdn.apache.org](https://dlcdn.apache.org/maven/)：镜像网络，列出当前的版本；
- [archive.apache.org](https://archive.apache.org/dist/maven/)：保存每个版本，包括旧版本。

两边都有的版本只列一次。Maven 4 的预览版，比如 `4.0.0-rc-7`，也会列出。

版本按 Maven 自己的发布顺序比较，而不是按文字：`3.10.1` 比 `3.9.16` 新，`4.0.0` 比 `4.0.0-rc-7` 新，`4.0.0-alpha-10` 比 `4.0.0-alpha-2` 新。

## 安装某个版本

版本按列表里的名字安装：

```bash
vfox install maven@3.10.1
vfox install maven@3.0.5
```

如果 dlcdn.apache.org 列出了这个版本，压缩包就来自那里；否则来自 archive.apache.org。两者的压缩包布局相同：`maven-<主版本>/<版本>/binaries/apache-maven-<版本>-bin.tar.gz`。

## 校验和

Apache 在每个压缩包旁边发布校验和文件：大多数版本是 `.sha512`，较旧的版本是 `.sha1` 或 `.md5`。插件读取所选源里存在的最强的那个文件，把其中的摘要交给 vfox。vfox 用它核对下载的内容，两者不一致时安装会停止。

## 不列出的版本

Maven 1 不列出。它唯一的版本 1.1 的压缩包布局不同，运行的命令是 `maven` 而不是 `mvn`。
