# 开发

[中文](development.md) | [English](../development.md)

## 目录结构

```
metadata.lua              插件名、版本和许可证
hooks/available.lua       vfox search：Maven 1 到 4 的版本，稳定版在前，预览版在后，各自从新到旧
hooks/pre_install.lua     vfox install：压缩包的地址和它的校验和
hooks/env_keys.lua        PATH：安装目录下的 bin 目录
hooks/pre_use.lua         vfox use：符合该写法的、已安装的最新版本，按 Maven 的顺序
hooks/post_install.lua    vfox 解压压缩包之后：无需操作
hooks/detect.lua          vfox link --detect maven：本机上已有的 Maven 目录
lib/util.lua              两个源、它们的列表、压缩包和校验文件
lib/maven_version.lua     Maven 版本的顺序，包括预览版
lib/detect_maven.lua      找出这些 Maven 目录：看它们的名字和启动脚本，以及去哪里找
tests/*_test.lua          离线测试，由 vfox plugin test 运行
tests/e2e/                端到端检查（一个 Go 测试）及其镜像，见 e2e.md
.devcontainer/            开发容器，见 e2e.md
.github/workflows/        lint、test、license、e2e 和发布
opencode.jsonc            让这个仓库里的 OpenCode 代理会话可以不经询问地运行 git push、gh pr create 和 gh pr comment
Injection.lua             vfox 注入对象的类型提示，从不加载
README*.md, docs/         文档，英文和 docs/zh-CN/ 中的中文
stylua.toml, .luarc.json  格式，以及 Lua 语言服务器的设置
.licenserc.yaml           许可证头检查
```

vfox 读取 `metadata.lua`，在某个命令需要时调用对应的钩子，并把 `PLUGIN` 和 `RUNTIME` 放进作用域。

## 每个命令会运行什么

| 你运行 | 钩子 |
| --- | --- |
| `vfox search maven` | `Available`，读取 dlcdn.apache.org 和 archive.apache.org 的列表 |
| `vfox install maven@3.10.1` | `PreInstall` 找到列出该版本的源，返回它的地址和校验和。vfox 下载、核对校验和并解压，然后调用 `PostInstall` |
| `vfox use maven@3.10.1` | `PreUse`，找出该写法对应的已安装版本，然后是 `EnvKeys`，它提供 `PATH` |
| `vfox link --detect maven` | `Detect`，返回本机上已有的 Maven 目录（`lib/detect_maven.lua`）。vfox 列出它们，链接你选中的，之后 `vfox use` 的用法和安装的版本一样 |

`PreUse` 负责 `vfox use` 的版本匹配。vfox 自己也会匹配，但它只比较版本的数字，所以 `maven@4` 可能选中 `4.0.0-alpha-2` 而不是 `4.0.0-alpha-13`。钩子按 Maven 的顺序选出已安装的最新版本；端到端检查会装上这两个版本，并检查 `vfox use maven@4` 选中的是哪一个。

安装用哪个源，跟随的是 dlcdn.apache.org 的列表，而不是校验文件。dlcdn.apache.org 会把一些旧版本的校验文件重定向到归档，而归档本身并不在 dlcdn.apache.org 上；所以 dlcdn.apache.org 给出的校验文件，并不能说明归档在哪里。

## 检查

在仓库根目录运行。这些就是 CI 运行的检查，开发容器里装的是同样版本的工具。

```bash
stylua --check .                                    # 格式（lint.yml）
lua-language-server --check . --checklevel=Warning  # Lua 诊断（lint.yml）
vfox plugin test .                                  # 离线测试（test.yml）
license-eye header check                            # 许可证头（license.yml）
```

端到端检查的 Go 代码在 `tests/e2e` 下检查：

```bash
gofmt -l .        # 格式正确时不输出任何内容
go vet ./...
go test -short ./...
```

格式不对时，运行 `stylua .` 或 `gofmt -w .` 修正。缺少许可证头时，运行 `license-eye header fix` 补上。

在链接的 git worktree 里，`.git` 是一个指向主仓库的文件。如果容器里看不到那个主仓库，许可证检查会把它报为没有头的文件。请在 clone 出来的副本上运行，和 CI 一样。

## 测试

`vfox plugin test .` 会在各自独立的虚拟机里运行 `tests/**/*_test.lua` 下的每个文件，所以新增文件不需要在任何地方登记。每个测试调用 `vfox.test` 的 `test.load()`，然后通过它返回的插件对象调用钩子。传给 `test.load` 的 `http` 函数负责回答插件发出的 HTTP 请求，因此测试不需要网络：

```lua
local test = require("vfox.test")
local plugin = test.load({
    http = function(request)
        return { status_code = 200, body = "..." }
    end,
})
local result = plugin:PreInstall({ version = "3.10.1" })
```

端到端检查（`tests/e2e`）用真实的插件访问 Apache 的服务器，见 [e2e.md](e2e.md)。

## 发布

维护者在默认分支上打开 **Actions → Plugin → Run workflow**，输入不带 `v` 前缀的稳定版本号。共享工作流 [plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action) 会更新 `metadata.lua`、创建版本提交和标签，并在本仓库发布 ZIP 和清单。不需要在本地打标签，也不需要额外的发布令牌。拉取请求只运行检查，PR 标题不会触发发布。

推送与 `PLUGIN.version` 一致的版本标签也会发布。如果发布失败，重新运行失败的任务即可继续。

工作流跟随共享的 `@v1` 发布工具，更新工具本身不会发布这个插件。包的约定和首次上线的要求，见共享工作流的文档。

## 发布之后

文档用「未发布」标出比上一个版本新的内容。版本发布后，把 [changes.md](changes.md) 里这些条目移到新版本下面，写上发布日期，并去掉这些标注，两种语言都要处理：`grep -rn -i -e unreleased -e 未发布 docs README*`。

## 已知的限制

- Maven 1.1 只能在 JDK 8 上运行，见 [versions.md](versions.md#maven-1)。
- `vfox link --detect maven` 找不到 Maven 1，它的文件里没有版本号。需要手动链接，见 [link.md](link.md)。
- Windows 上，`--detect` 只从 jar 的名字读取版本，因为没有可以询问的启动脚本。jar 名字里没有版本号的 Maven 在那里找不到。
- CI 在 Linux amd64 和 arm64 上，以及 Windows x86_64 和 arm64 上运行端到端检查。Windows arm64 上 Maven 1.1 用 x64 的 JDK 8 通过模拟运行，见 [e2e.md](e2e.md)。

## 文档的写法

英文页面在 `docs/`，中文页面在 `docs/zh-CN/`，文件名相同，每个页面顶部都链接到另一种语言的版本。两个 README 分别是 `README.md` 和 `README_CN.md`。
