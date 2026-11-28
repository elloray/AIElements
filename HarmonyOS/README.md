# AIElements for HarmonyOS

The gallery includes all 67 entries from the shadcn/ui component indexes (Base UI, Radix UI, and React Aria). Search the **shadcn/ui** section to open a native example. [Public API and usage](../Documentation/Shadcn-Components.md) · [Light and dark comparisons](../Documentation/Images/Shadcn/README.md)

原生 ArkTS + ArkUI 组件库，面向 HarmonyOS NEXT 5.0（API 12）及以上的手机和平板。

- `aielements` 提供 21 个 AI 界面模式、15 种基础节点、JSONL 流式协议和原生渲染器。它可以作为单个 HAR 接入应用。
- `gallery` 提供可搜索的本地示例、手机列表与详情、平板双栏、系统／浅色／深色外观，以及支持回放和停止的流式仪表盘。
- 界面沿用 Geist、Geist Mono 和 Lucide。资源许可见[第三方声明](../THIRD_PARTY_NOTICES.md)。

## 构建与运行

用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开 `HarmonyOS/`，选择支持 API 12 的 HarmonyOS SDK，完成项目同步。运行配置选择 `gallery`。真机调试使用 DevEco Studio 的本地签名配置。

使用 [HarmonyOS 命令行工具](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/ide-command-line-building-app-V5/) 时，从本目录执行：

```sh
ohpm install --all
hvigorw --mode module -p module=aielements@default -p buildMode=release assembleHar
hvigorw --mode module -p module=gallery@default -p product=default -p buildMode=debug assembleHap
```

构建产物位于各模块的 `build/default/outputs/default/`。画廊的 Bundle ID 为 `dev.aielements.gallery`。项目配置中未包含签名证书。

## 接入已有项目

在宿主模块的 `oh-package.json5` 中添加本地依赖。路径相对于宿主模块，可指向源码目录或已构建的 HAR。

```json5
{
  "dependencies": {
    "@aielements/arkui": "file:../../AIElements/HarmonyOS/aielements"
  }
}
```

```arkts
import {
  AIChat, AIChatMessage, AIMessageRole, AIPromptInput, AIPromptSubmission,
  registerAIElementsFonts
} from '@aielements/arkui';

@Component
export struct AssistantPane {
  @State private draft: string = '';
  @State private messages: AIChatMessage[] = [];
  private nextID: number = 0;

  aboutToAppear(): void {
    registerAIElementsFonts();
  }

  private submit(value: AIPromptSubmission): void {
    this.messages = this.messages.concat({
      id: String(++this.nextID),
      role: AIMessageRole.User,
      text: value.text
    });
    this.draft = '';
    // 将消息交给宿主服务，并用稳定的消息 ID 更新响应。
  }

  build() {
    Column({ space: 12 }) {
      AIChat({ messages: this.messages }).layoutWeight(1)
      AIPromptInput({
        text: this.draft,
        onTextChange: value => { this.draft = value; },
        onSubmit: value => this.submit(value)
      })
    }.width('100%').height('100%').padding(16)
  }
}
```

聊天需要宿主提供有界高度。传入 `attachments` 和 `onAttachmentsChange` 可接入系统文档选择器，宿主负责消费 URI 并清空已接收附件。模型调用、审批决策、命令执行与数据持久化由宿主管理。库颜色跟随应用外观。

## 组件目录

| 用途 | 公开 API |
| --- | --- |
| 会话与输入 | `AIChat`、`AIChatHeader`、`AIMessage`、`AIMessageResponse`、`AIMessageActions`、`AIPromptInput`、`AIModelSelector`、`AISuggestion`、`AISuggestions` |
| 任务与过程 | `AIChainOfThought`、`AIReasoning`、`AIPlan`、`AIQueue`、`AITask`、`AISubagent`、`AIContext` |
| 操作与检查 | `AICheckpoint`、`AIConfirmation`、`AIFileTree`、`AITool`、`AITerminal`、`AIStackTrace`、`AITestResults` |
| 来源 | `AISources`、`AIInlineCitation`、`AICitedText` |
| 基础布局与内容 | `AIStack`、`AIRow`、`AICard`、`AIText`、`AISeparator` |
| 基础控件 | `AIButton`、`AIBadge`、`AIInput`、`AISelect`、`AISwitch`、`AIProgress` |
| 数据展示 | `AITable`、`AIBarChart`、`AILineChart`、`AIAreaChart` |

`AIMessageResponse` 支持段落、标题、粗体、行内代码、HTTP(S) 链接和围栏代码。表格可横向滚动，图表可点选数据并展开值列表。API 使用 ArkUI 的属性、回调和 Builder 插槽，各平台的组件签名有差异。

## 流式 UI

```arkts
private store: AIUIStore = new AIUIStore();

// 在 ArkUI build() 中
AIUIRenderer({ store: this.store, onEvent: event => this.handleEvent(event) })

// 在收到数据和连接关闭时
this.store.receive(chunk);
this.store.finish();
```

`receive` 接受任意切分的 `Uint8Array`，包括被拆开传输的 UTF-8 字符。若传输层已经按行解码，可用 `receiveLine`。在 UI 线程更新 store。失序或无效更新会保留最后一帧和错误信息。重播时用 `reset()`，本地输入仅回传动作声明的状态键。完整节点和事件契约见[流式协议](../Documentation/StreamingUI.md)。

## 验证

```sh
./tests/run.sh
```

需要 Node.js 22+、npm 和 Python 3。9 项测试覆盖 UTF-8 字节流、失序和中断、表单状态、动作输出、Markdown 解析、图表几何和 shadcn 数据表的稳定行 ID 与筛选。更新共享样例后，运行 `python3 sync-fixtures.py` 同步应用随包资源。

已用 OpenHarmony API 12 SDK 检查 ArkTS、编译字节码并打包资源，未签名 HAP 通过完整性检查。SDK Previewer 已渲染 67 个 shadcn 组件的浅深色示例。真机安装和交互仍待验证。[逐项对照与测量](../Documentation/Shadcn-Components.md)
