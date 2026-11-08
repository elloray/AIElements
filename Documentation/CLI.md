# CLI 与 AI 编程工具

`aielements` 是本仓库随源码分发的 Swift 命令行工具，目前支持 macOS 14+、Swift 5.9+。
组件库仍支持 iOS/iPadOS 17+ 和 macOS 14+。CLI 目标只依赖 Foundation，不依赖 SwiftUI 库目标；App 产品不包含 CLI 的目录和 Skill。

## 安装与更新

在仓库根目录运行：

```sh
sh Scripts/install-cli.sh --prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
aielements version
```

脚本从当前 checkout 构建 release 版本，将二进制和资源 bundle 安装到 `<prefix>/lib/aielements/`，在 `<prefix>/bin/aielements` 写入启动脚本。它不使用 sudo，不修改 shell 配置，不调用网络安装器。Swift 工具链需要预先安装。

已有安装会被拒绝覆盖。更新时，可选择新 prefix 并调整 PATH，或先把自己已有的 `lib/aielements` 目录和 `bin/aielements` 启动脚本移到备份位置，再运行安装。Skill 也不自动覆盖：先把旧 Skill 文件夹移到备份位置，再安装新的版本。库、CLI 和 Skill 应来自匹配的 checkout，避免 API 不一致。

不需要固定安装时，使用：

```sh
swift run --package-path /path/to/AIElements aielements list --json
```

不要仅复制可执行文件：SwiftPM 资源 bundle 必须一起保留。安装脚本已处理这一点。当前 `aielements version` 表示 CLI 的版本，不能当作组件库已有的 Git tag；组件库目前仍使用 `main` 或 commit SHA 接入。

## 命令

| 命令 | 输出／效果 |
| --- | --- |
| `list [--search TEXT]` | 21 个组件；按 slug、英文名、中文摘要和 Swift 符号搜索 |
| `show COMPONENT` | 符号、源码相对路径、行为说明、上游设计链接、完整 Swift 示例 |
| `example COMPONENT` | 只在 stdout 输出完整 Swift 文件，不自行写文件 |
| `init --path NEW_DIR [--name AssistantUI]` | 创建可被宿主 App 引用的 SwiftUI Package |
| `skill print` | 输出随 CLI 分发的 SKILL.md |
| `skill install --path NEW_SKILL_DIR` | 将 SKILL.md 写入指定的新目录 |
| `version` / `--version` | CLI 版本 |
| `help` / `--help` / `-h` | 完整语法 |

组件参数接受 `file-tree`、`"File Tree"` 或 `AIFileTree`；符号与名字忽略大小写。

所有命令支持 `--json`。`init` 和 `skill install` 支持 `--dry-run`，其 JSON 输出列出目标路径、文件名和将写入的完整内容。已有目标（包括空目录或符号链接）会报错，不提供隐式覆盖模式。

`init` 额外支持：

| 参数 | 含义 |
| --- | --- |
| `--name NAME` | 默认 `AssistantUI`；以大写英文字母开头，仅含字母和数字，最长 64 字符；不能与依赖模块重名 |
| `--local-package PATH` | 引用含 Package.swift 的本机库目录，生成显式命名的本地依赖 |
| `--revision SHA` | 引用远程仓库的完整 40 位提交 SHA；与 `--local-package` 互斥 |

省略以上依赖参数时使用远程 `main`。本地依赖写入绝对路径，适合本机开发；分享生成的 Package 前换成远程依赖。

## 自动化输出约定

- 标准输出是命令结果，不包含进度日志。使用 `swift run` 时 SwiftPM 自身可能在 stderr 输出构建信息；需要严格 JSON 协议时调用安装后的 `aielements`。
- JSON 顶层 `schemaVersion` 固定为整数 `1`。消费者应容忍新增字段。
- `list` 含 `components` 数组；`show` / `example` 含 `component`、`code` 和 `attribution`。
- 写入命令含 `dryRun`、`destination` 和 `files`（每项为 `path`、`content`）。
- 失败时 stdout 为空；stderr 为人类可读文本，或 `--json` 下的 `{schemaVersion, exitCode, message}`。
- 退出码 `0` 成功，`2` 参数／目标冲突，`1` 读写或其他运行错误。没有匹配的搜索仍成功，返回空数组。
- 查询、示例生成和 Skill 安装均不联网、不执行命令片段、不读取模型凭据。之后自行构建生成的远程 Package 时，SwiftPM 会获取依赖。

## Skill 的作用与边界

[aielements-swiftui](../Tools/Skills/aielements-swiftui/SKILL.md) 使用通用 SKILL.md 格式，可单独复制，不依赖当前机器的路径。它在需要时查询 CLI；CLI 不可用时可读取库 checkout 中的目录及示例。

项目级安装：Codex 使用 `.agents/skills/aielements-swiftui`，Claude Code 使用 `.claude/skills/aielements-swiftui`。目录与加载行为见 [Codex 官方文档](https://developers.openai.com/codex/skills)、[Claude Code 官方文档](https://code.claude.com/docs/en/skills)。其他工具是否自动发现由其自身实现决定；不支持 Skill 的工具仍可直接调用 CLI。

Skill 不授予额外执行权限，不替宿主选择模型提供商，不更改签名身份。生成的聊天示例是本地 UI，模型调用、取消、审批后的执行以及附件上传由宿主负责。它同时保留非官方 shadcn/ui 移植的来源声明。

## 维护与验证

单一组件目录位于 `Tools/Catalog/catalog.json`，源码示例位于 `Tools/Catalog/Examples/`，Skill 位于 `Tools/Skills/`。SwiftPM 将它们原样打包，查询无需访问仓库目录。修改公共 API 时同步修改相关示例和说明。

```sh
swift test --filter CLIKitTests
python3 Scripts/validate-cli.py --ios
```

第一条检查 CLI 的查询、JSON 输出、参数错误、预览、生成和覆盖保护。第二条运行真实 CLI，生成临时消费者 Package，将 21 个示例全部编译到 macOS 和 iOS Simulator 目标，并验证特殊字符路径、revision 依赖及 Skill 安装。该脚本需要 Python 3 和完整 Xcode；不加 `--ios` 只检查 macOS。它不调用模型服务，也不安装或启动模拟器 App。

仅改工具链时无需重复截图验证；修改 SwiftUI 组件时仍按 [组件验证范围](VALIDATION.md) 验证对应平台和外观。
