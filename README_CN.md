# 简介

[中文](README_CN.md) | [English](README.md)

vfox-maven 是 [vfox](https://vfox.lhan.me/) 的一个插件，用来安装 [Apache Maven](https://maven.apache.org/)：也就是 Apache 在 [dlcdn.apache.org](https://dlcdn.apache.org/maven/) 和 [archive.apache.org](https://archive.apache.org/dist/maven/) 上发布的 Maven 1、2、3 和 4 版本，包括旧版本。

# 安装

安装 vfox 之后，运行下面的命令添加插件：

```bash
vfox add maven
```

Maven 需要 Java 运行时，这个插件不会安装它。请把 JDK 放进 `PATH`，或者设置 `JAVA_HOME`。[vfox-java](https://github.com/version-fox/vfox-java) 插件可以安装 JDK。Maven 1.1 只能在 JDK 8 上运行。

# 用法

```bash
vfox search maven                # 插件列出的版本，包括旧版本
vfox install maven@3.10.1        # 安装一个版本，会核对它的校验和
vfox use --global maven@3.10.1   # 设为全局版本
vfox link --detect maven         # 采用本机上已有的 Maven
mvn --version
```

# 文档

- [版本](docs/zh-CN/versions.md)：列出哪些版本、从哪里下载、怎样校验
- [本机已有的 Maven](docs/zh-CN/link.md)：用 `vfox link --detect maven` 采用本机上的 Maven
- [变更记录](docs/zh-CN/changes.md)：每个版本改了什么
- [开发](docs/zh-CN/development.md)：目录结构、测试、检查和发布
- [端到端检查与开发容器](docs/zh-CN/e2e.md)

英文文档是 [README.md](README.md) 和 [docs/](docs/)。
