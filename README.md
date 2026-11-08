# AIElements for SwiftUI

**A native SwiftUI port of [shadcn/ui AI Elements](https://ui.shadcn.com/docs/ai-elements), for iOS, iPadOS, and macOS.**

将 shadcn/ui AI Elements 的 21 个界面模式实现为可复用的 SwiftUI 组件。包含浅深色主题、Geist 字体、Lucide 矢量图标和可交互示例，无第三方运行时依赖。

同时提供 **`aielements` CLI + `aielements-swiftui` Agent Skill**：让 AI 编程工具查询当前组件 API、读取完整 Swift 示例，并生成可接入现有 App 的 UI Package。[直接开始使用 CLI 和 Skill ↓](#ai-编程工具cli--skill)

> **非官方项目 / Unofficial port**：原始界面模式、视觉设计及参考示例来自 [shadcn/ui](https://github.com/shadcn-ui/ui)。本仓库由 elloray 独立维护，不隶属于 shadcn、shadcn/ui 或 Vercel，也不代表其官方 Swift 产品或背书。原作者及资源许可详见 [致谢与许可](#致谢与许可)。

![SwiftUI Tool 组件深色预览](Documentation/Images/tool-dark.png)

## 平台与范围

- iOS / iPadOS **17+**，macOS **14+**；Swift tools **5.9+**。
- 同一个 `AIElements` Swift Package 产品用于两端。
- 组件提供界面、状态呈现和回调；模型调用、命令执行、附件上传及数据持久化由宿主负责。
- 以 2026-11-05 保存的官方目录为最初范围，并持续对照原站复核；21 个模式不等于原站所有子状态或旧版 AI SDK Elements 的全部组件。

## 安装

### Xcode

选择 **File → Add Package Dependencies…**，输入：

```text
https://github.com/elloray/AIElements.git
```

当前使用 **Branch → main**，将 **AIElements** 产品加入 App target，然后 `import AIElements`。`main` 会随开发更新；需要固定构建时可锁定具体 commit。当前尚未发布语义化版本 tag。

### Swift Package Manager

```swift
// Package.swift
let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/elloray/AIElements.git", branch: "main")
    ],
    targets: [
        .target(name: "MyApp", dependencies: [
            .product(name: "AIElements", package: "AIElements")
        ])
    ]
)
```

本地开发也可用 `.package(path: "../AIElements")`，或在 Xcode 中选择 **Add Local…**。

## AI 编程工具：CLI + Skill

CLI 在 **macOS 14+ / Swift 5.9+** 上运行，不依赖 Node.js 或模型 API。它与 SwiftUI 库分开构建；App 引用 `AIElements` 时不会带入 CLI 和 Skill 资源。

### 安装 CLI

```bash
git clone https://github.com/elloray/AIElements.git
cd AIElements
sh Scripts/install-cli.sh --prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
aielements help
```

安装脚本会一起复制可执行文件和所需资源 bundle；不要只移动二进制。将 PATH 配置加入你使用的 shell 后，其他项目也能调用。无需安装时，在库目录运行 `swift run aielements …`；在其他目录运行 `swift run --package-path /path/to/AIElements aielements …`。

### 查询和生成

```bash
aielements list --json
aielements list --search "文件树"
aielements show AIFileTree --json
aielements example chat

# 先查看将生成的内容，再创建新目录。
aielements init --path ./AssistantUI --name AssistantUI --dry-run --json
aielements init --path ./AssistantUI --name AssistantUI
```

`show` 返回符号、源码位置、使用约束、原站链接和完整 Swift 示例；`example` 只输出源码。21 个组件均有示例，随 CLI 离线分发。JSON 含 `schemaVersion: 1`，失败时错误写入 stderr 并返回非零状态。

`init` 生成 **可复用的 SwiftUI Package**，不是完整 Xcode App。将生成的目录作为本地 Package 加入现有 App，链接 `AssistantUI` 产品后使用：

```swift
import AssistantUI

// 在宿主 View 中：
AssistantChatView()
```

生成的界面只接收本地消息，AI 请求由宿主接入。远程依赖默认跟踪 `main`；可用 `--revision <完整 commit SHA>` 固定版本，或 `--local-package /path/to/AIElements` 引用本机库。生成器和 Skill 安装命令均拒绝覆盖已有目录。

### 给 AI 工具安装 Skill

在**要开发的 App 项目根目录**执行对应命令，`--path` 是完整的 Skill 目录：

```bash
# Codex：项目级 Skill
aielements skill install --path .agents/skills/aielements-swiftui

# Claude Code：项目级 Skill
aielements skill install --path .claude/skills/aielements-swiftui
```

项目目录遵循 [Codex Skills 文档](https://developers.openai.com/codex/skills)和 [Claude Code Skills 文档](https://code.claude.com/docs/en/skills)。安装后可在 Codex 中使用 `$aielements-swiftui`，或在 Claude Code 中使用 `/aielements-swiftui`。未出现时重新打开项目会话。其他支持 `SKILL.md` 的工具可按其约定复制 [Skill 目录](Tools/Skills/aielements-swiftui)；也可用 `aielements skill print` 读取全文。

例如，在 Codex 中输入：

```text
使用 $aielements-swiftui，为当前 App 加一个 AI 聊天页。
先查 chat、prompt-input、reasoning、tool 的 CLI 示例，沿用项目现有的模型服务。
支持 iOS 和 macOS、系统浅深色，iOS 保留 44 pt 触控区。
发送失败保留草稿和附件，流式响应保持消息 ID 稳定，停止按钮取消请求。
```

Skill 指导工具选择组件、接入状态与回调并验证宿主构建；不会安装模型 SDK、执行示例中的终端命令或替你配置凭据。完整命令、更新方法和验证脚本见 [CLI 指南](Documentation/CLI.md)。

## 快速开始

```swift
import SwiftUI
import AIElements

struct AssistantView: View {
    @State private var draft = ""
    @State private var messages: [AIChatMessage] = []
    @State private var submissionRevision = 0

    var body: some View {
        VStack(spacing: 16) {
            AIChat(messages: messages)
            AIPromptInput(text: $draft, attachmentResetID: submissionRevision) { submission in
                messages.append(.init(
                    role: .user,
                    text: submission.text,
                    parts: submission.attachments.map { .attachment($0) }
                ))
                draft = ""
                submissionRevision += 1
                // 在这里调用自己的 AI 服务，并把响应写入 messages。
            }
        }
        .padding()
    }
}
```

也可以独立组合轨迹、工具和推理内容：

```swift
AITrace {
    AIReasoning("检查相关文件。", duration: 2)
    AITool("swift test", status: .completed, output: "All tests passed.")
}
```

示例中的命令和响应仅用于展示，组件不会执行这些命令。

## 21 个模式

下表第一列链接到 **shadcn/ui 的原始模式文档**；第二列是本项目提供的 SwiftUI API。

| 官方模式 | SwiftUI API | 主要行为 |
| --- | --- | --- |
| [Chain of Thought](https://ui.shadcn.com/docs/ai-elements/base/chain-of-thought) | `AIChainOfThought` | 汇总与嵌套步骤展开 |
| [Chat](https://ui.shadcn.com/docs/ai-elements/base/chat) | `AIChat`, `AIConversation` | 用户回合锚点、消息片段、流式跟随、回到底部 |
| [Checkpoint](https://ui.shadcn.com/docs/ai-elements/base/checkpoint) | `AICheckpoint` | 恢复回调 |
| [Confirmation](https://ui.shadcn.com/docs/ai-elements/base/confirmation) | `AIConfirmation` | 异步审批、失败重试、审批后工具状态 |
| [Context](https://ui.shadcn.com/docs/ai-elements/base/context) | `AIContext` | 用量百分比、详情与进度 |
| [File Tree](https://ui.shadcn.com/docs/ai-elements/base/file-tree) | `AIFileTree` | 保留子树展开状态、可控展开、文件选择 |
| [Inline Citation](https://ui.shadcn.com/docs/ai-elements/base/inline-citation) | `AICitedText`, `AIInlineCitation` | 原生行内引用、悬停／点击预览、多来源翻页 |
| [Message](https://ui.shadcn.com/docs/ai-elements/base/message) | `AIMessage`, `AIMessageResponse`, `AIMessageActions` | 角色、Markdown、复制／重试／反馈 |
| [Model Selector](https://ui.shadcn.com/docs/ai-elements/base/model-selector) | `AIModelSelector` | 分组模型与推理强度选择 |
| [Plan](https://ui.shadcn.com/docs/ai-elements/base/plan) | `AIPlan` | 计划步骤与完成计数 |
| [Prompt Input](https://ui.shadcn.com/docs/ai-elements/base/prompt-input) | `AIPromptInput` | 多行文本、文件选择、移除附件、发送／停止 |
| [Queue](https://ui.shadcn.com/docs/ai-elements/base/queue) | `AIQueue` | 待办／完成分组与选择回调 |
| [Reasoning](https://ui.shadcn.com/docs/ai-elements/base/reasoning) | `AIReasoning` | 流式展开、用时、手动折叠 |
| [Sources](https://ui.shadcn.com/docs/ai-elements/base/sources) | `AISources` | 来源列表与外部链接 |
| [Stack Trace](https://ui.shadcn.com/docs/ai-elements/base/stack-trace) | `AIStackTrace` | 错误与栈帧、源码跳转回调 |
| [Subagent](https://ui.shadcn.com/docs/ai-elements/base/subagent) | `AISubagent` | 子任务内容组合与结果 |
| [Suggestion](https://ui.shadcn.com/docs/ai-elements/base/suggestion) | `AISuggestion`, `AISuggestions` | 横向建议与选择回调 |
| [Task](https://ui.shadcn.com/docs/ai-elements/base/task) | `AITask` | 任务步骤展开 |
| [Terminal](https://ui.shadcn.com/docs/ai-elements/base/terminal) | `AITerminal` | 命令、输出、运行／错误状态 |
| [Test Results](https://ui.shadcn.com/docs/ai-elements/base/test-results) | `AITestResults` | 测试套件、失败详情与跳过状态 |
| [Tool](https://ui.shadcn.com/docs/ai-elements/base/tool) | `AITool` | 状态映射、输出折叠、长输出 Sheet |

基础构件还包括 `AITrace`、`AITraceLine`、`AITraceDisclosure`、`AICodeBlock`、`AIAttachmentView`、`AIIcon`、`AITextLabel`、`AIBadge` 和 `AIButtonStyle`。

## 主题与原生适配

默认跟随系统外观，也可以显式指定：

```swift
YourView()
    .aiTheme(.dark)
    .preferredColorScheme(.dark)
```

字体资源自动注册，无需在宿主 Info.plist 中添加字体配置，也不会修改全局 UIAppearance。

iOS 默认使用 `.comfortable` 密度，为交互保留至少 **44 pt 的独立触控区域**；macOS 默认 `.reference` 密度。因此 iOS 的部分列表会比网页更高，这是有意的原生适配。可按宿主场景选择：

```swift
YourView().aiControlDensity(.comfortable)
YourView().aiControlDensity(.reference)
```

更多内容见 [使用指南](Documentation/Usage.md)：受控状态、流式更新、审批、消息片段、原生引用、附件、键盘行为与自定义样式。

## 运行示例

```bash
git clone https://github.com/elloray/AIElements.git
cd AIElements
swift run AIElementsGallery
```

上面的命令运行 macOS 组件画廊。iOS / iPadOS 示例用 Xcode 打开：

```bash
open Examples/AIElementsDemo.xcodeproj
```

选择 `AIElementsDemo` + iPhone / iPad Simulator，或 `AIElementsMac` + My Mac。示例工程默认禁用签名，用于模拟器和本机预览；真机运行需由使用者配置自己的签名身份。

`Examples/project.yml` 是 XcodeGen 源文件；只在需要重新生成工程时运行：

```bash
xcodegen generate --spec Examples/project.yml
```

## 验证与已知差异

项目以原站为视觉基准，已对 21 个默认示例及待审批态进行 **360 CSS px / pt、2×、浅深色、iOS / macOS** 对照。最新本地验证记录：iOS 包测试 30 项、macOS 包测试 29 项，以及 8 项针对性交互测试通过。详见 [验证范围](Documentation/VALIDATION.md)。

```bash
swift test
swift run AIElementsGallery --snapshots
```

第二条命令生成本机截图，不提交生成物。仓库保留精选预览；反复生成的历史截图、构建缓存和机器日志不纳入版本控制。

![Inline Citation 同宽对比：Web、iOS、macOS](Documentation/Images/citation-comparison-light.png)

**还原目标不等于零像素误差。** SwiftUI、UIKit / AppKit 与浏览器仍有字形栅格化、系统菜单、输入法和取整差异；iOS 触控布局也刻意保留原生可用性。没有覆盖原站每个动画和悬停状态，也没有实测所有最低支持系统版本。

Markdown 支持常见富文本、列表、表格、图片及流式代码块；数学公式、Mermaid 和额外的语法高亮器可由宿主接入。此包不包含模型供应商 SDK。

## 致谢与许可

本项目的核心视觉参考来自 **[shadcn/ui AI Elements](https://ui.shadcn.com/docs/ai-elements)**。感谢 [shadcn](https://github.com/shadcn) 及 [shadcn/ui 贡献者](https://github.com/shadcn-ui/ui/graphs/contributors) 提供这些界面模式和示例。

| 来源 | 本项目中的用途 | 许可 |
| --- | --- | --- |
| [shadcn/ui](https://github.com/shadcn-ui/ui) | 原始 AI Elements 模式、视觉参考、示例及 `Reference/` 快照 | [MIT](https://github.com/shadcn-ui/ui/blob/main/LICENSE.md)，保留 Copyright (c) 2023 shadcn |
| [Geist / Geist Mono](https://github.com/vercel/geist-font) | 随包分发的未修改字体 | [SIL OFL 1.1](Sources/AIElements/Resources/Geist-LICENSE) |
| [Lucide](https://lucide.dev) | 转换为 SwiftUI 路径的图标 | [ISC](Sources/AIElements/Resources/Lucide-LICENSE) |

Swift 实现以 [MIT License](LICENSE) 分发。第三方材料仍遵循各自许可；完整声明和原始版权文本见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。使用本项目时请保留适用的版权及许可声明。

**Unofficial and independently maintained. Not affiliated with, sponsored by, or endorsed by shadcn, shadcn/ui, or Vercel.**
