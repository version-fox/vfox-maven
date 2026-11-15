# 端到端检查与开发容器

[中文](e2e.md) | [English](../e2e.md)

离线测试无法确认 vfox 能否安装真正的 Maven，所以由端到端检查来完成这件事。它是 `tests/e2e` 里的一个 Go 测试，用真实的 vfox 访问 Apache 的真实归档。

## 检查什么

对 `vfox search maven` 列出的最新 Maven 4 和 Maven 3 版本，以及三个归档版本 Maven 3.0.5、Maven 2.2.1 和 Maven 1.1，检查以下几点：

1. `vfox add maven --source` 加入插件（从仓库打包 `metadata.lua`、`hooks` 和 `lib`），`vfox search maven` 列出归档版本；
2. `vfox install` 安装版本，输出显示 vfox 核对了校验和；
3. `vfox use --global` 选中版本：在已激活 vfox 的 shell 里，Maven 命令（`mvn`，Maven 1 是 `maven`）解析到该版本，报告该版本并能运行；
4. 插件的 EnvKeys 钩子通过 `vfox plugin run` 运行，把该版本的 bin 目录放进 `PATH`。

然后是三个场景，检查 `vfox use` 的其他作用域：

- 为会话选中的版本（`vfox use`）覆盖全局选择，会话随 shell 结束；
- `vfox use --project` 为项目目录选中版本，写入 `.vfox.toml`，项目之外仍然使用全局选择；
- `vfox use` 只写大版本号（`maven@3`）时，选中已安装的该大版本的最新版本。

`vfox use` 只在已激活 vfox 的 shell 里生效，就像用户的 shell 那样，所以场景在这样的 shell 里运行：Linux 和 macOS 用 bash，Windows 用 PowerShell 7。脚本依次执行 `vfox activate`、`vfox use`、`vfox env`（脚本不会触发应用 `vfox env` 的提示符钩子），然后运行 Maven 命令。`VFOX_MAVEN_SHELL`（`bash` 或 `pwsh`）可以覆盖这个选择，因此 PowerShell 的路径也能在 Linux 上运行。这些 shell 的环境里会去掉 vfox 会话的变量（`__VFOX_*`），因此不会继承启动检查的那个 shell 的会话。

测试使用自己的家目录（`HOME` 和 `USERPROFILE` 都指向临时目录），因此机器上 vfox 的缓存和全局选择不会被改动。

## 需要什么

- `PATH` 上的 vfox 1.1.0。
- Maven 2 到 4 用的 Java 运行时，即默认的 JDK。
- `VFOX_MAVEN_JAVA8_HOME`：一个带 `lib/tools.jar` 的 JDK 8，给 Maven 1.1 用。它的启动脚本会传 `-Djava.endorsed.dirs`，JDK 9 及以后拒绝这个选项，所以 Maven 1 只能在 JDK 8 上运行。
- Linux 和 macOS 上的 bash，Windows 上的 PowerShell 7（`pwsh`）。
- 网络，用于访问 Apache 的服务器。

`VFOX_MAVEN_PLUGIN_DIR` 指定插件的仓库目录，默认是存放这个测试的仓库。

## 运行

在 `tests/e2e` 目录下：

```bash
go test -v -run '^TestE2E$' -timeout 40m .
```

单元测试不需要网络，加上 `-short` 只运行它们：

```bash
go test -short ./...
```

## 在 CI 中

- `e2e.yml`，Linux：用 `go test -c` 为运行器的架构编译检查，然后在端到端镜像（`tests/e2e/Dockerfile`）里运行，仓库以只读方式挂载。运行器是 `ubuntu-latest`（amd64）和 `ubuntu-26.04-arm`（arm64）。
- `e2e.yml`，Windows：检查直接在 `windows-latest` 上运行，使用 PowerShell 7。`setup-java` 安装一个给 Maven 1.1 用的 JDK 8，和作为默认的 JDK 21。
- `lint.yml`：对 Go 代码运行 `gofmt`、`go vet` 和 `go test -short`。

## 开发容器

`.devcontainer/` 描述了开发容器：lint、测试和许可证工作流所用的工具（版本与这些工作流一致）、测试工作流使用的 vfox 版本、一个 Java 运行时，以及给 Maven 1.1 用的 JDK 8。可以用 VS Code 的 Dev Containers 等工具打开仓库，或者运行 `docker build --tag vfox-maven-dev .devcontainer` 构建镜像。

在开发容器里从源码运行检查：

```bash
docker run --rm --volume "$PWD:/src:ro" --env VFOX_MAVEN_PLUGIN_DIR=/src -w /src/tests/e2e vfox-maven-dev go test -count=1 -v -run '^TestE2E$' -timeout 40m .
```

在 Linux 主机上用端到端镜像运行检查，需要先为主机编译测试二进制，再把它挂载进去：

```bash
(cd tests/e2e && CGO_ENABLED=0 go test -c -o /tmp/e2e.test .)
docker build --tag vfox-maven-e2e tests/e2e
docker run --rm --volume "$PWD:/src:ro" --volume /tmp/e2e.test:/usr/local/bin/e2e.test:ro --env VFOX_MAVEN_PLUGIN_DIR=/src vfox-maven-e2e e2e.test -test.run '^TestE2E$' -test.v -test.timeout 40m
```

## 已知的限制

- 检查只安装最新的 Maven 3 和 Maven 4 版本，以及三个归档版本，而不是 `vfox search` 列出的每一个版本。
- 场景使用插件默认的 `PreUse`，它什么也不做：版本的匹配由 vfox 负责。
