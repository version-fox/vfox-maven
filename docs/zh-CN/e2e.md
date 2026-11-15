# 端到端检查与开发容器

[中文](e2e.md) | [English](../e2e.md)

离线测试无法确认 vfox 能否安装真正的 Maven，所以由 `tests/e2e/run.sh` 来完成这件事。它在端到端镜像（`tests/e2e/Dockerfile`）里运行。镜像包含 Ubuntu、Java 运行时、zip，以及测试工作流固定的 vfox 版本。

脚本做以下几件事：

1. 把 `metadata.lua`、`hooks` 和 `lib` 打成 zip，用 `vfox add maven --source` 把它加入 vfox；
2. 取 `vfox search maven` 列出的最新 Maven 3 和最新 Maven 4 版本，再加上两个归档中的历史版本：Maven 3.0.5 和 Maven 2.2.1，它们只有 archive.apache.org 有；
3. 对这四个版本分别执行：`vfox install`（必须核对校验和）、`vfox use --global`，然后通过 `vfox env` 运行 `mvn --version`，报告的版本必须正确。

脚本使用自己的 HOME，因此机器上 vfox 的全局选择和 SDK 链接不会被改动。

## 在 CI 中

`.github/workflows/e2e.yml` 从 `tests/e2e` 构建镜像，并在其中运行 `run.sh`，仓库以只读方式挂载。CI 只在 Linux amd64 上运行它。

## 在本地

使用 Docker：

```bash
docker build --tag vfox-maven-e2e tests/e2e
docker run --rm --volume "$PWD:/src:ro" vfox-maven-e2e bash /src/tests/e2e/run.sh
```

或者在装有 vfox 1.1.0、zip 和 Java 运行时的机器上，从仓库根目录运行 `bash tests/e2e/run.sh`。

## 开发容器

`.devcontainer/` 描述了开发容器：lint、测试和许可证工作流所用的工具（版本与这些工作流一致）、测试工作流使用的 vfox 版本，以及一个 Java 运行时，因此 `tests/e2e/run.sh` 也能在其中运行。可以用 VS Code 的 Dev Containers 等工具打开仓库，或者运行 `docker build --tag vfox-maven-dev .devcontainer` 构建镜像。

在开发容器里运行端到端检查：

```bash
docker run --rm --volume "$PWD:/src:ro" -w /src vfox-maven-dev bash tests/e2e/run.sh
```

## 已知的限制

- CI 只在 Linux amd64 上运行这项检查。
- 只安装最新的 Maven 3 和 Maven 4 版本，加上两个归档中的历史版本，而不是 `vfox search` 列出的每一个版本。
