# 使用指南

## 组合与受控状态

```swift
AITrace {
    AIReasoning(reasoningText, isStreaming: isThinking, duration: 5)
    AITool("swift test", status: .completed, output: testOutput)
    AISources(sources)
}

// AITraceDisclosure 可由宿主控制，也可通过 defaultOpen 自行管理。
AITraceDisclosure("Read project files", isExpanded: $expanded) {
    AIFileTree(files, selection: $selectedPath)
}
```

自定义用户气泡时，使用 `AIMessageText` 保持与网页一致的单词换行、22.75 pt 行高和短消息自然宽度；`AIChat` 已默认采用它：

```swift
AIMessage(role: .user) {
    AIMessageText("Migrate the dialog components to Base UI.")
}
```

代码输出按实际字体宽度折行，选择复制仍返回原始文本，不会带入显示时新增的换行。普通 Markdown 段落使用 20 pt 行高；轨迹中的摘要使用 22.75 pt 行高和次级文字色。

传入稳定的 `id`，保证流式更新时折叠、反馈等状态不丢失。修改聊天消息最后一项的 `text` 即可更新流式内容；自定义消息组合可使用 `AIConversation(revision:)`，并在内容变动时更新 revision。


## 原生行内引用与消息片段

```swift
AICitedText([
    .text("回答会随数据到达逐步显示。 "),
    .source(.init(title: "Streaming", url: URL(string: "https://nextjs.org")!)),
    .text(" 引用会与正文一起换行。")
])

let reply = AIChatMessage(id: "reply-1", role: .assistant, parts: [
    .reasoning(text: "检查相关文件。", isStreaming: false, duration: 2),
    .tool(name: "read Package.swift", status: .completed, output: "..."),
    .text("项目同时支持 **iOS 和 macOS**。")
])
```

`AIChat` 提供 `onEdit`、`onRetry` 和 `messageContent` 自定义渲染入口。`AIMessage` 的 `footer` 插槽把用户操作放在气泡外；`AIMessageActions` 的 `feedback` / `onFeedbackChange` 支持选择和取消反馈。

## 执行状态与展开控制

`AIToolPhase.status(streaming:clientTool:)` 是不绑定模型 SDK 的状态适配器，覆盖输入流、审批、初步输出、完成、失败和拒绝。初步输出不会提前显示完成，客户端工具等待结果时不会被误判失败。

`AIChainOfThought`、`AIPlan`、`AITask`、`AISubagent`、`AIReasoning`、`AITool`、`AITerminal` 和 `AITestResults` 可传入 `isExpanded`。未指定展开状态时，运行／错误内容按对应模式自动显示；用户手动选择或显式 `defaultOpen` 优先。`AIStep.content` 支持文本、Markdown、代码和来源，`stepContent` 可进一步自定义。

审批可传 `submitDecision` 异步闭包：提交期间禁止重复操作，失败保留审批卡并显示错误；通过 `executionStatus` 和 `output` 呈现批准后的执行过程。`AITerminal.exitCode` 为非零时显示错误；文件树的 `expandedPaths` 可绑定宿主状态。

在结构化聊天中，用 `.toolApproval(id: requestID, name: command, input: details)` 表示一次需要用户决定的调用。把 `onToolApproval` 传给 `AIChat`，根据回调中的请求 ID 和决定更新对应消息。批准后把该 part 替换为运行中的 `.tool`，收到结果再改为完成或失败。拒绝时改为 `.tool(..., status: .denied)`。回调抛错会保留审批卡，供用户重试。

`AIReasoning` 默认保留原文的空格、换行和 Markdown 标记，可以用 `rendersMarkdown: true` 开启富文本。空来源列表默认隐藏，`showsEmptyState: true` 可显示空态。`AITestResults(suites: [], isRunning: true, command: command)` 表示正在启动测试，`commandError` 用于显示测试命令启动失败的原因。

详细修复对照与验证范围见 [FIXES.md](FIXES.md) 和 [VALIDATION.md](VALIDATION.md)。

## 主题与字体

默认跟随系统浅色／深色模式。字体资源自动注册，不需要修改宿主 Info.plist。仅影响组件内部，不设置全局 UIAppearance。

```swift
YourView().aiTheme(.dark)
YourView().preferredColorScheme(.dark) // 同时改变系统弹出层外观

var custom = AITheme.light
custom.radius = 12
YourView().aiTheme(custom)
```

正文采用原站 Geist 14pt、代码 Geist Mono 12pt、Lucide 16pt / 2px stroke；使用 `Font.custom(..., relativeTo: .body)` 支持 Dynamic Type。运行态 shimmer 尊重 Reduce Motion。

自定义按钮可用 `AITextLabel("Replay", weight: .medium)` 作为 label，再应用 `AIButtonStyle`，以沿用组件的 macOS 字体绘制。它保留原字体字重及 Dynamic Type，不修改全局设置；可选择的正文仍使用 `AIMessageResponse` 或 `AICodeBlock`。

iOS 默认使用 `.comfortable` 密度：保持紧凑按钮外观，但为交互留出至少 44pt 的独立区域；macOS 默认 `.reference` 密度。需要严格按网页布局嵌入时，可显式选择：

```swift
YourView().aiControlDensity(.reference)   // 原站紧凑间距
YourView().aiControlDensity(.comfortable) // 44pt 触控区域
```

窄屏和辅助功能字号下，模型选择器会改为纵向排布。

## 附件和提交

`AIPromptInput` 支持受控或内部管理的附件：传入 `attachments: $files` 时由宿主管理；省略绑定时组件会自行保存，仍可正常选择、移除和发送附件。`attachmentResetID` 变化时清空内部附件，适合在宿主确认提交成功后重置。失败时不要改变此值，以保留草稿。

内置文件选择器可用 `onAttach` 替换。支持拖入文件 URL、粘贴文件／图片，以及 `AIAttachmentPolicy` 的类型、大小、数量约束。选择失败会直接显示在输入框下方，并通知 `onAttachmentError`。小图片可显示预览；粘贴图片通过 `AIAttachment.data` 交付。组件读取文件元信息或预览时临时打开安全作用域；上传、长期保存、后续 URL 读取与访问授权仍由宿主管理。

`onSubmit` 仅在有文本或附件且未运行时触发。组件不会自动清空输入；宿主接收成功后再清空，避免提交失败时丢失草稿。`onAttachmentError` 可接入宿主日志或提示；运行时 `onStop` 由宿主取消请求。

macOS 支持 Enter 发送、Shift+Enter 换行，组合输入期间回车交由输入法处理。iOS 软件键盘保留换行，外接键盘支持 Enter 发送。macOS 模型菜单使用系统菜单的方向键、Enter 和 Esc 行为；两端保留原站的触发器外观。

