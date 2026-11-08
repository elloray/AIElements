# CLI 与 AI 编程工具

`aielements` 是本仓库随源码分发的 Swift 命令行工具，目前支持 macOS 14+、Swift 5.9+。
组件库仍支持 iOS/iPadOS 17+ 和 macOS 14+。CLI 目标只依赖 Foundation，不依赖 SwiftUI 库目标；App 产品不包含 CLI 的目录和 Skill。

## Clone 后直接使用

推荐让 AI 工具按 [README 中的提示](../README.md#ai-编程工具cli--skill)自行 clone 并读取 Skill。也可以手动执行：

```sh
git clone https://github.com/elloray/AIElements.git
cd AIElements
./aielements help
./aielements show chat --json
```

仓库根目录的 `aielements` 脚本会自动构建和运行 CLI，并复用 SwiftPM 缓存，不需要安装或配置 PATH。在宿主项目目录用 `/path/to/AIElements/aielements …` 调用即可；生成文件的相对路径仍以**调用时的工作目录**为准。保留 checkout，后续即可继续查询。

Skill 可以直接读取 `Tools/Skills/aielements-swiftui/SKILL.md`，不要求预先注册到 AI 工具。按需更新 checkout 时保留本地改动，并让工具与宿主锁定的库版本保持一致。

以下命令表中的命令均接在 `./aielements`（或 checkout 的完整脚本路径）后面。

## 可选：固定安装与更新

在仓库根目录运行：

```sh
sh Scripts/install-cli.sh --prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
aielements version
```

脚本从当前 checkout 构建 release 版本，将二进制和资源 bundle 安装到 `<prefix>/lib/aielements/`，在 `<prefix>/bin/aielements` 写入启动脚本。它不使用 sudo，不修改 shell 配置，不调用网络安装器。Swift 工具链需要预先安装。

已有安装会被拒绝覆盖。更新时，可选择新 prefix 并调整 PATH，或先把自己已有的 `lib/aielements` 目录和 `bin/aielements` 启动脚本移到备份位置，再运行安装。Skill 也不自动覆盖：先把旧 Skill 文件夹移到备份位置，再安装新的版本。库、CLI 和 Skill 应来自匹配的 checkout，避免 API 不一致。

入口脚本等价于下面的 SwiftPM 命令：

```sh
swift run --package-path /path/to/AIElements aielements list --json
```

不要仅复制可执行文件：SwiftPM 资源 bundle 必须一起保留。安装脚本已处理这一点。当前 `aielements version` 表示 CLI 的版本，不能当作组件库已有的 Git tag；组件库目前仍使用 `main` 或 commit SHA 接入。

## 命令

| 命令 | 输出／效果 |
| --- | --- |
| `list [--search TEXT]` | 37 个条目：21 个 AI 模式、15 种基础节点、1 个流式接入示例；支持 slug、英文名、中文摘要、Swift 符号和协议类型搜索 |
| `show COMPONENT` | 符号、源码相对路径、行为说明、上游设计链接、完整 Swift 示例 |
| `example COMPONENT` | 只在 stdout 输出完整 Swift 文件，不自行写文件 |
| `ui schema` | 输出文档与流式事件的 JSON Schema |
| `ui example [NAME]` | 输出完整 JSON 文档；默认 dashboard，或指定任一基础节点 slug |
| `ui stream` | 输出逐步生成 dashboard 的 JSONL 事件 |
| `ui validate PATH` | 验证完整 `.json` 文档或成功结束的 `.jsonl` 流，包括节点图、绑定和 revision 语义 |
| `init --path NEW_DIR [--name AssistantUI]` | 创建可被宿主 App 引用的 SwiftUI Package |
| `skill print` | 输出随 CLI 分发的 SKILL.md |
| `skill install --path NEW_SKILL_DIR` | 将 SKILL.md 写入指定的新目录 |
| `version` / `--version` | CLI 版本 |
| `help` / `--help` / `-h` | 完整语法 |

组件参数接受 `file-tree`、`"File Tree"`、`AIFileTree`，也接受协议类型名 `LineChart`；符号与名字忽略大小写。三个图表共用 `AIChart`，直接 `show AIChart` 会提示选择具体图表 slug。JSON 目录中的可选 `protocolType` 标记基础节点；`symbols` 为空表示通过 `AIUIRenderer` 使用，不存在独立的 Swift 构造器。

所有命令支持 `--json`。`init` 和 `skill install` 支持 `--dry-run`，其 JSON 输出列出目标路径、文件名和将写入的完整内容。已有目标（包括空目录或符号链接）会报错，不提供隐式覆盖模式。

`init` 额外支持：

| 参数 | 含义 |
| --- | --- |
| `--name NAME` | 默认 `AssistantUI`；以大写英文字母开头，仅含字母和数字，最长 64 字符；不能与依赖模块重名 |
| `--local-package PATH` | 引用含 Package.swift 的本机库目录，生成显式命名的本地依赖 |
| `--revision SHA` | 引用远程仓库的完整 40 位提交 SHA；与 `--local-package` 互斥 |

省略以上依赖参数时使用远程 `main`。本地依赖写入绝对路径，适合本机开发；分享生成的 Package 前换成远程依赖。

## 基础组件与流式 UI

`ui example` 支持：`dashboard`、`stack`、`row`、`card`、`text`、`button`、`badge`、`input`、`select`、`switch`、`progress`、`separator`、`table`、`bar-chart`、`line-chart`、`area-chart`。

```sh
./aielements list --search chart --json
./aielements show select
./aielements example line-chart        # SwiftUI 完整源码
./aielements example streaming-ui      # 逐段接收、结束和中断的 Swift 接入示例
./aielements ui example select > /tmp/select.json
./aielements ui validate /tmp/select.json --json
./aielements ui stream > /tmp/report.jsonl
./aielements ui validate /tmp/report.jsonl --json
```

Swift 示例展示原生 API 或协议渲染器；JSON 示例包含需要的状态绑定和事件声明。`Stack`、`Row`、`Text`、`Badge`、`Separator` 通过渲染器组合，没有对应的独立构造器；原有 `AIBadge` 并非协议 Badge 的五变体接口。

实际接入时，每收到一段 JSONL 字节即在 MainActor 调用 `AIUIStore.receive`，EOF 时调用 `finish`，取消或失败时调用 `interrupt`，重试前 `reset`。`finish` 后还要检查 `session.phase/errorMessage`，缺少 `surface.complete` 也会失败。SSE 需要先提取完整 data 事件并解码后调用 `apply`。更新会替换整个命名节点，需保留它的 bindings/events/children；避免重复发送初始表单 state 覆盖用户输入。

`ui validate` 面向完整交付数据；尚在生成中的部分 JSONL 会被拒绝。模型调用、传输、取消、已知操作分发和持久化由宿主负责。完整生命周期、节点属性、回调及限制见 [流式 UI 指南](StreamingUI.md)，视觉范围见 [基础组件双端验收](Foundation-Visual-Validation.md)。

## 自动化输出约定

- 标准输出是命令结果，不包含进度日志。使用 checkout 入口或 `swift run` 时 SwiftPM 自身可能在 stderr 输出构建信息；需要严格 JSON 协议时调用安装后的 `aielements`。
- CLI 结果封装的 `schemaVersion` 固定为整数 `1`。消费者应容忍新增字段。**`ui schema/example/stream` 是例外**：始终输出原始协议文件，即使传入 `--json`；文档和事件使用协议 `version: "1.0"`，Schema 使用 `$schema`。
- `list` 含 `components` 数组；`show` / `example` 含 `component`、`code` 和 `attribution`。
- 写入命令含 `dryRun`、`destination` 和 `files`（每项为 `path`、`content`）。
- 失败时 stdout 为空；stderr 为人类可读文本，或 `--json` 下的 `{schemaVersion, exitCode, message}`。
- `ui validate --json` 返回 `{schemaVersion, valid, revision}`。退出码 `0` 成功，`2` 参数／目标冲突或未成功结束的流，`1` 读写、协议验证或其他运行错误。没有匹配的搜索仍成功，返回空数组；验证失败按非零状态处理。
- 查询、示例生成和 Skill 安装均不联网、不执行命令片段、不读取模型凭据。之后自行构建生成的远程 Package 时，SwiftPM 会获取依赖。

## Skill 的作用与边界

[aielements-swiftui](../Tools/Skills/aielements-swiftui/SKILL.md) 使用通用 SKILL.md 格式，可单独复制，不依赖当前机器的路径。它在需要时查询 CLI；CLI 不可用时可读取库 checkout 中的目录及示例。

如果希望 AI 工具自动发现 Skill，可在宿主项目目录执行 `/path/to/AIElements/aielements skill install --path <目标 Skill 目录>`。项目级安装：Codex 使用 `.agents/skills/aielements-swiftui`，Claude Code 使用 `.claude/skills/aielements-swiftui`。目录与加载行为见 [Codex 官方文档](https://developers.openai.com/codex/skills)、[Claude Code 官方文档](https://code.claude.com/docs/en/skills)。其他工具是否自动发现由其自身实现决定；不支持 Skill 的工具仍可直接调用 CLI。

Skill 不授予额外执行权限，不替宿主选择模型提供商，不更改签名身份。生成的聊天示例是本地 UI，模型调用、取消、审批后的执行以及附件上传由宿主负责。它同时保留非官方 shadcn/ui 移植的来源声明。

## 维护与验证

组件查询目录位于 `Tools/Catalog/catalog.json`，Swift 示例位于 `Tools/Catalog/Examples/`，Skill 位于 `Tools/Skills/`；协议 Schema、JSON/JSONL 示例位于 `Sources/AIElementsUIProtocol/Resources/`，资源名称在 `AIUIResources.exampleNames` 中维护。SwiftPM 将资源打包，查询无需访问仓库目录。修改公共 API 或协议时同步修改相关示例和说明。

```sh
swift test --filter CLIKitTests
python3 Scripts/validate-cli.py --ios
```

第一条检查 CLI 的查询、JSON 输出、参数错误、预览、生成和覆盖保护。第二条运行真实 CLI，验证 16 份完整 JSON 文档和完整/未完成 JSONL，生成临时消费者 Package，将 37 个 Swift 示例全部编译到 macOS 和 iOS Simulator 目标，并验证特殊字符路径、revision 依赖及 Skill 安装。该脚本需要 Python 3 和完整 Xcode；不加 `--ios` 只检查 macOS。它不调用模型服务，也不安装或启动模拟器 App。

仅改工具链时无需重复截图验证；修改 SwiftUI 组件时仍按 [组件验证范围](VALIDATION.md) 验证对应平台和外观。
