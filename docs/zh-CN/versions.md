# 版本

[中文](versions.md) | [English](../versions.md)

`vfox search maven` 列出 Apache 发布的每个 Maven 1、2、3 和 4 版本，最新的在前。列表来自两个地方：

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

如果 dlcdn.apache.org 列出了这个版本，压缩包就来自那里；否则来自 archive.apache.org。Maven 2 到 4 的压缩包布局相同：`maven-<主版本>/<版本>/binaries/apache-maven-<版本>-bin.tar.gz`，只有一个例外。Maven 2.0.11 安装的是 `apache-maven-2.0.11-bin.zip`，因为它的 `tar.gz` 里有一个多余的零块，vfox 的解包会拒绝它。

## 使用某个版本

`vfox use` 优先使用以写出的名字安装的版本。否则使用符合该写法、已安装的最新版本，排序如上：装了 `4.0.0-alpha-2` 和 `4.0.0-alpha-13` 时，`maven@4` 使用 `4.0.0-alpha-13`。写法按整段匹配，所以 `3.1` 不匹配 `3.10.1`。没有符合的已安装版本时，vfox 报告该版本未安装，不会去安装它。

```bash
vfox use --global maven@4
```

## 校验和

Apache 在每个压缩包旁边发布校验和文件：大多数版本是 `.sha512`，较旧的版本是 `.sha1` 或 `.md5`。插件读取所选源里存在的最强的那个文件，把其中的摘要交给 vfox。vfox 用它核对下载的内容，两者不一致时安装会停止。

## Maven 1

Maven 1 只有一个版本，1.1。它的压缩包是 `maven-1/1.1/binaries/maven-1.1.tar.gz`，唯一的校验文件是 `.md5`，其中摘要以字节对的形式写在文件名之后；运行的命令是 `maven`。

Maven 1.1 只能在 JDK 8 上运行。它的启动脚本会传 `-Djava.endorsed.dirs`，JDK 9 及以后拒绝这个选项；它还要读 `lib/tools.jar`，所以需要的是 JDK 而不是 JRE。运行前请把 `JAVA_HOME` 指向一个 JDK 8。
