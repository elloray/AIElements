# Android 第三轮精修与原站重拍 · 2026-11-11

在 `codex/android-port` 完成表格与聊天细节修正后，本轮重新采集 **36 种组件、37 个状态、浅深色共 74 张原站截图和 74 张 Android 截图**，逐项审阅 74 组并排对照。

[逐项图库](Images/AndroidPrecision-2026-11-11/index.html) · [尺寸与来源](../Reference/android-visual-precision-2026-11-11.json) · [上一轮](Android-Visual-Polish-2026-11-11.md)

## 本轮修正

- **表格行高**：将分隔线绘制在行内，避免独立 1 dp 分隔线在 2.625 倍密度下逐行向上取整。原站普通行 37 px、表头 40 px、末行 36.5 px；Android 保留字号放大后自动增高和横向滚动。
- **表格列宽**：按表头、普通正文、强调列各自的实际字重测量内容，空余宽度按列的固有宽度分配。360 宽度下金额完整显示。
- **聊天重置按钮**：通过公开的 `visualAlignment` 对齐可见图形，不移动或缩小 48 dp 点击区域。默认图标按钮仍保持居中。
- 新增 1.5 倍字号、320 dp 表格检查，确认相邻行不重叠，横向滚动可访问金额；保留原有重置按钮回调和独立点击区域检查。
- 本轮未改截图样例，也未为截图添加专用字体、偏移或颜色。70/74 张 Android 截图与上一轮字节一致；仅 Chat / Table 浅深色四张发生变化。

| 状态 | 原站高度 | 上轮 Android | 当前 Android | 当前高度差 |
| --- | ---: | ---: | ---: | ---: |
| Table | 371.50 | 374.86 | 371.43 | -0.07 |
| Chat | 800.00 | 800.00 | 800.00 | 0.00（按钮位置已对齐） |

## 比较口径

- 左原站、右 Android，统一 360 CSS px / 360 dp，保留自然高度。File Tree 内宽 320；Input / Select / Progress 内宽分别为 320 / 192 / 216。八个小控件居中放入 360×64 对照画布，64 不是控件本身高度。
- Android 15 / API 35 模拟器，默认字号、密度 2.625，组件原图宽 945 px。本轮两侧均重新截图；原站的全部文案、展开状态和测量尺寸与上一轮一致。
- 原站仅临时调整预览宽度、视口和主题，没有改写组件内容或布局规则；采集后恢复并关闭临时页面。
- 排除进度条 13% 和图表绘制中的中间帧，最终记录为 66% 进度以及完整图表。图表在页面完成加载后核对浅深色背景，等待 SVG 动画几何稳定并刷新绘制帧，避免把动画或后台画面缓存误判为 Android 缺陷。
- 并排图按 sRGB 处理。网页 JPEG、原生 PNG 和两端字体栅格化不同，不用像素相似度分数冒充视觉一致率。

## 逐项剩余差异

“明显 / 中 / 轻”表示视觉差异程度，不是功能严重等级。

| 组件 | 差异 | 原站 / Android 高度 | 当前差异 | 浅色 | 深色 |
| --- | --- | ---: | --- | --- | --- |
| [Chain of Thought](https://ui.shadcn.com/docs/ai-elements/base/chain-of-thought) | 中 | 288.0 / 297.5 | 展开入口及回答仍偏下；总高仅多 9.5，不能掩盖正文起点约 28 的位移。主要关联 48 dp 展开行。 | [查看](Images/AndroidPrecision-2026-11-11/chain-of-thought-light.png) | [查看](Images/AndroidPrecision-2026-11-11/chain-of-thought-dark.png) |
| [Chat](https://ui.shadcn.com/docs/ai-elements/base/chat) | 轻 | 800.0 / 800.0 | 重置按钮的可见圆面向上、向右各对齐 8 dp，独立 48 dp 点击区保持不变；标题、说明和空态已接近。仍有细微字体基线、说明占宽及输入框位置差异。 | [查看](Images/AndroidPrecision-2026-11-11/chat-light.png) | [查看](Images/AndroidPrecision-2026-11-11/chat-dark.png) |
| [Checkpoint](https://ui.shadcn.com/docs/ai-elements/base/checkpoint) | 中 | 288.0 / 290.7 | Restore 已改为弱化色、中等字重；分隔区仍较高，第二组消息下移。 | [查看](Images/AndroidPrecision-2026-11-11/checkpoint-light.png) | [查看](Images/AndroidPrecision-2026-11-11/checkpoint-dark.png) |
| [Confirmation 初始态](https://ui.shadcn.com/docs/ai-elements/base/confirmation) | 轻 | 288.0 / 288.0 | 可见按钮在 288 高画布内仍约高 10；按钮自身的形状接近。 | [查看](Images/AndroidPrecision-2026-11-11/confirmation-light.png) | [查看](Images/AndroidPrecision-2026-11-11/confirmation-dark.png) |
| [Confirmation 待审批](https://ui.shadcn.com/docs/ai-elements/base/confirmation) | 中 | 288.0 / 327.6 | Deny/Approve 已在面板内垂直居中；两侧说明均为两行，上轮“多换一行”的判断不成立。Thought 和 Reset 的点击范围仍使面板及总高度偏下。 | [查看](Images/AndroidPrecision-2026-11-11/confirmation-approval-light.png) | [查看](Images/AndroidPrecision-2026-11-11/confirmation-approval-dark.png) |
| [Context](https://ui.shadcn.com/docs/ai-elements/base/context) | 轻 | 124.0 / 144.0 | 胶囊外观接近；独立 48 dp 点击范围使画布增高 20，中心向下偏 10。 | [查看](Images/AndroidPrecision-2026-11-11/context-light.png) | [查看](Images/AndroidPrecision-2026-11-11/context-dark.png) |
| [File Tree](https://ui.shadcn.com/docs/ai-elements/base/file-tree) | 明显 | 244.0 / 384.0 | 7 个可点击行均为 48，网页为 28，累计高出 140；缩进和浅色选中底色已改善。保留触控尺寸时，这一密度差仍会存在。 | [查看](Images/AndroidPrecision-2026-11-11/file-tree-light.png) | [查看](Images/AndroidPrecision-2026-11-11/file-tree-dark.png) |
| [Inline Citation](https://ui.shadcn.com/docs/ai-elements/base/inline-citation) | 轻 | 374.0 / 369.5 | 主要断行已接近；徽标占位、圆底宽度和文本基线仍有细差，最后一段总高度略少。 | [查看](Images/AndroidPrecision-2026-11-11/inline-citation-light.png) | [查看](Images/AndroidPrecision-2026-11-11/inline-citation-dark.png) |
| [Message](https://ui.shadcn.com/docs/ai-elements/base/message) | 中 | 434.2 / 459.8 | 行号右移 4，行号至代码的间距由 16 缩至 12，命令起点保持不变。原站与 Android 命令横向起点已接近；主要差异仍为操作图标 48 对比 28 的中心间距、消息纵向位置和细微字体基线。 | [查看](Images/AndroidPrecision-2026-11-11/message-light.png) | [查看](Images/AndroidPrecision-2026-11-11/message-dark.png) |
| [Model Selector](https://ui.shadcn.com/docs/ai-elements/base/model-selector) | 轻 | 160.0 / 160.4 | 32 高的模型/Effort 胶囊、文字边距与外框已接近；横向位置、文字基线和深色边框仍有小差别。 | [查看](Images/AndroidPrecision-2026-11-11/model-selector-light.png) | [查看](Images/AndroidPrecision-2026-11-11/model-selector-dark.png) |
| [Plan](https://ui.shadcn.com/docs/ai-elements/base/plan) | 中 | 367.5 / 409.1 | 静态步骤间距接近；可展开标题较高，使步骤连接线、回答与 Replay 整体下移。 | [查看](Images/AndroidPrecision-2026-11-11/plan-light.png) | [查看](Images/AndroidPrecision-2026-11-11/plan-dark.png) |
| [Prompt Input](https://ui.shadcn.com/docs/ai-elements/base/prompt-input) | 轻 | 160.0 / 160.4 | 整体尺寸与内部可见控件已接近，仍有少量控件横向偏移、占位文字基线和边框差异。 | [查看](Images/AndroidPrecision-2026-11-11/prompt-input-light.png) | [查看](Images/AndroidPrecision-2026-11-11/prompt-input-dark.png) |
| [Queue](https://ui.shadcn.com/docs/ai-elements/base/queue) | 明显 | 344.8 / 473.5 | 4 个任务行仍比网页高 20 左右；去除额外行间距后，回答及 Replay 仍明显下移。 | [查看](Images/AndroidPrecision-2026-11-11/queue-light.png) | [查看](Images/AndroidPrecision-2026-11-11/queue-dark.png) |
| [Reasoning](https://ui.shadcn.com/docs/ai-elements/base/reasoning) | 中 | 417.2 / 459.0 | 正文恢复 22.75 行高，并以一个空行的高度分段，随字号缩放。第一段仍受 48 dp 展开入口影响而偏下；总高增大是恢复文字节奏后的真实结果，没有再压缩行距抵消入口高度。 | [查看](Images/AndroidPrecision-2026-11-11/reasoning-light.png) | [查看](Images/AndroidPrecision-2026-11-11/reasoning-dark.png) |
| [Sources](https://ui.shadcn.com/docs/ai-elements/base/sources) | 明显 | 339.5 / 448.4 | 三条来源行仍使用独立 48 dp 区域，Replay 明显下移；文本起点与层级线大体接近，剩余细差以字体基线为主。 | [查看](Images/AndroidPrecision-2026-11-11/sources-light.png) | [查看](Images/AndroidPrecision-2026-11-11/sources-dark.png) |
| [Stack Trace](https://ui.shadcn.com/docs/ai-elements/base/stack-trace) | 明显 | 384.8 / 513.9 | 源码行和框架入口仍更松；错误正文与后续回答下移，红色较鲜。两侧均有层级竖线，不能将竖线本身误判为多余。 | [查看](Images/AndroidPrecision-2026-11-11/stack-trace-light.png) | [查看](Images/AndroidPrecision-2026-11-11/stack-trace-dark.png) |
| [Subagent](https://ui.shadcn.com/docs/ai-elements/base/subagent) | 明显 | 459.8 / 557.3 | 内层正文已继承展开区域的 22.75 行高。工具入口仍逐项增高，说明和回答下移；长命令省略位置仍不同。 | [查看](Images/AndroidPrecision-2026-11-11/subagent-light.png) | [查看](Images/AndroidPrecision-2026-11-11/subagent-dark.png) |
| [Suggestion](https://ui.shadcn.com/docs/ai-elements/base/suggestion) | 中 | 196.0 / 224.4 | 渐隐效果已存在，但 48 dp 建议行加外部间隔使输入框比网页低约 28；第三条建议的露出范围也不同。 | [查看](Images/AndroidPrecision-2026-11-11/suggestion-light.png) | [查看](Images/AndroidPrecision-2026-11-11/suggestion-dark.png) |
| [Task](https://ui.shadcn.com/docs/ai-elements/base/task) | 中 | 299.5 / 368.4 | 两个工具入口使后续回答和 Replay 下移；正文路径的折行位置也不同。 | [查看](Images/AndroidPrecision-2026-11-11/task-light.png) | [查看](Images/AndroidPrecision-2026-11-11/task-dark.png) |
| [Terminal](https://ui.shadcn.com/docs/ai-elements/base/terminal) | 明显 | 532.8 / 613.3 | 三个命令入口使输出块下移；长命令/表格断行不同。底部渐隐与圆角已补齐，当前差别不能归为缺失渐隐。 | [查看](Images/AndroidPrecision-2026-11-11/terminal-light.png) | [查看](Images/AndroidPrecision-2026-11-11/terminal-dark.png) |
| [Test Results](https://ui.shadcn.com/docs/ai-elements/base/test-results) | 明显 | 502.2 / 599.6 | 测试文件与失败项入口逐层增高，错误块和结论下移；堆栈路径的换行位置不同。 | [查看](Images/AndroidPrecision-2026-11-11/test-results-light.png) | [查看](Images/AndroidPrecision-2026-11-11/test-results-dark.png) |
| [Tool](https://ui.shadcn.com/docs/ai-elements/base/tool) | 明显 | 320.2 / 401.9 | 三条工具入口比网页高，错误输出和结论随之下移；代码字形、内距有细差。 | [查看](Images/AndroidPrecision-2026-11-11/tool-light.png) | [查看](Images/AndroidPrecision-2026-11-11/tool-dark.png) |
| [Stack](https://ui.shadcn.com/docs/components/base/separator) | 轻 | 113.0 / 113.9 | 高度差已缩到约 0.9，剩余是标题/分隔线基线和边缘细差。 | [查看](Images/AndroidPrecision-2026-11-11/stack-light.png) | [查看](Images/AndroidPrecision-2026-11-11/stack-dark.png) |
| [Row](https://ui.shadcn.com/docs/components/base/badge) | 轻 | 64.0 / 64.0（画布） | 四个徽标排列已接近；单项字形占宽、边框与底色仍有小差别。 | [查看](Images/AndroidPrecision-2026-11-11/row-light.png) | [查看](Images/AndroidPrecision-2026-11-11/row-dark.png) |
| [Card](https://ui.shadcn.com/docs/components/base/card) | 中 | 357.0 / 378.3 | 去掉卡片正文的重复 16 间距和页脚多余 8 留白；Forgot 文本已贴齐字段右边界。密码框和页脚仍较原站偏下，按钮间的视觉间隔较宽，关联独立 48 dp 编辑/点击行。 | [查看](Images/AndroidPrecision-2026-11-11/card-light.png) | [查看](Images/AndroidPrecision-2026-11-11/card-dark.png) |
| [Text](https://ui.shadcn.com/docs/components/base/separator) | 轻 | 40.0 / 40.4 | 正文换行一致，高度只多约 0.4；主要是字形栅格化细差。 | [查看](Images/AndroidPrecision-2026-11-11/text-light.png) | [查看](Images/AndroidPrecision-2026-11-11/text-dark.png) |
| [Button](https://ui.shadcn.com/docs/components/base/button) | 轻 | 64.0 / 64.0（画布） | 可见高度约 32，形状接近；宽度、文字基线和边缘有细差。64 为对照画布高度。 | [查看](Images/AndroidPrecision-2026-11-11/button-light.png) | [查看](Images/AndroidPrecision-2026-11-11/button-dark.png) |
| [Badge](https://ui.shadcn.com/docs/components/base/badge) | 轻 | 64.0 / 64.0（画布） | 浅色错误底色已修正；标签宽度、文字和圆角边缘仍有细差。 | [查看](Images/AndroidPrecision-2026-11-11/badge-light.png) | [查看](Images/AndroidPrecision-2026-11-11/badge-dark.png) |
| [Input](https://ui.shadcn.com/docs/components/base/input) | 轻 | 64.0 / 64.0（画布） | 320 内宽、32 可见高度接近；深色填充和边框更明显，文字起点略不同。 | [查看](Images/AndroidPrecision-2026-11-11/input-light.png) | [查看](Images/AndroidPrecision-2026-11-11/input-dark.png) |
| [Select](https://ui.shadcn.com/docs/components/base/select) | 轻 | 64.0 / 64.0（画布） | 192 内宽、32 可见高度接近；文字/箭头基线、深色边框与填充仍有细差。 | [查看](Images/AndroidPrecision-2026-11-11/select-light.png) | [查看](Images/AndroidPrecision-2026-11-11/select-dark.png) |
| [Switch](https://ui.shadcn.com/docs/components/base/switch) | 轻 | 64.0 / 64.0（画布） | 轨道尺寸、滑块和标签关系接近；边缘与字形占宽略不同。 | [查看](Images/AndroidPrecision-2026-11-11/switch-light.png) | [查看](Images/AndroidPrecision-2026-11-11/switch-dark.png) |
| [Progress](https://ui.shadcn.com/docs/components/base/progress) | 轻 | 64.0 / 64.0（画布） | 216 宽、4 高、66% 进度一致；起点圆角与像素边缘略不同。 | [查看](Images/AndroidPrecision-2026-11-11/progress-light.png) | [查看](Images/AndroidPrecision-2026-11-11/progress-dark.png) |
| [Separator](https://ui.shadcn.com/docs/components/base/separator) | 轻 | 64.0 / 64.0（画布） | 360 宽、1 高一致；细线明暗与像素取整略不同。 | [查看](Images/AndroidPrecision-2026-11-11/separator-light.png) | [查看](Images/AndroidPrecision-2026-11-11/separator-dark.png) |
| [Table](https://ui.shadcn.com/docs/components/base/table) | 轻 | 371.5 / 371.4 | 分隔线改为行内绘制，消除逐行像素取整累积；按实际字重测量并分配列宽。总高 371.43 对比 371.50，差约 -0.07；列边界、文本基线与线条明暗仍有细差。 | [查看](Images/AndroidPrecision-2026-11-11/table-light.png) | [查看](Images/AndroidPrecision-2026-11-11/table-dark.png) |
| [Bar Chart](https://ui.shadcn.com/view/new-york-v4/chart-bar-default) | 轻 | 354.4 / 354.7 | 高度差仅约 0.3，标题/页脚对齐明显改善；柱色、网格线和边缘仍不同。 | [查看](Images/AndroidPrecision-2026-11-11/bar-chart-light.png) | [查看](Images/AndroidPrecision-2026-11-11/bar-chart-dark.png) |
| [Line Chart](https://ui.shadcn.com/view/new-york-v4/chart-line-default) | 轻 | 354.4 / 354.7 | 自然曲线形状、布局已接近；描边颜色、细网格与抗锯齿仍不同，高度差约 0.3。 | [查看](Images/AndroidPrecision-2026-11-11/line-chart-light.png) | [查看](Images/AndroidPrecision-2026-11-11/line-chart-dark.png) |
| [Area Chart](https://ui.shadcn.com/view/new-york-v4/chart-area-default) | 中 | 354.4 / 354.7 | 自然曲线及高度接近（高差约 0.3）。已核实原站面积透明度为 0.4、网格为 5% 白色；深色填充在截图中仍略有色差，未凭压缩截图改写色值。 | [查看](Images/AndroidPrecision-2026-11-11/area-chart-light.png) | [查看](Images/AndroidPrecision-2026-11-11/area-chart-dark.png) |

## 验证与结论

- 调试 APK、发布 AAR、Android 测试 APK 构建通过；Lint 0 错误、13 警告（既有依赖更新提示和 Modifier 参数位置建议）。
- 一次完整设备回归 **23/23 通过**，其中包括全部 74 状态截图、大字号表格、重置回调、输入菜单、独立触控区域、审批重试和折叠内容恢复。
- 完成 20 张原生整屏检查：手机浅深色 6 张、大字号 2 张、手机横屏 4 张、平板横竖屏各 4 张，覆盖 Chat / Table 和手机 Message。模拟器系统界面曾出现无响应弹窗，前台窗口检查已拒绝受遮挡采集，重启后补拍；无效画面未加入图库。
- 本轮不改协议和图表几何，未重复运行对应单元测试。验证范围为 API 35 模拟器，未新增真机或最低系统版本覆盖。

表格高度与聊天按钮对齐已改善。当前最明显的差异仍是 File Tree（+140）、Queue（约 +129）、Stack Trace（约 +129）、Sources（约 +109）的独立 48 dp 点击行，以及 Message 工具栏 48 对比 28 的图标中心间距。Card 页脚、展开内容、代码换行和细微字形/色彩差异仍如表中所列；**并未达到像素级一致**。

![表格精修后](Images/AndroidPrecision-2026-11-11/table-light.png)

![聊天精修后](Images/AndroidPrecision-2026-11-11/chat-light.png)

[来源及构建指纹](../Reference/android-visual-precision-evidence-2026-11-11.json)。原始网页/Android 截图、前后源码和测试日志位于 `.build/android-polish3-2026-11-11/`。
