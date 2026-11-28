# shadcn/ui 原生组件

SwiftUI、Jetpack Compose 和 ArkUI 均实现了 2026-11-28 三个官方组件目录合计的 67 个组件。Base UI 有 66 项，Radix UI 有 67 项，React Aria 有 65 项。同名组件优先对照 Base UI，Sonner 使用 Radix UI 的官方示例。三端画廊可以按英文名搜索，每一项都能独立嵌入宿主 App。每项选取一个具名示例或示例中的组件区域进行浅深色比对。[Base UI 目录](https://ui.shadcn.com/docs/components) · [Radix UI](https://ui.shadcn.com/docs/components/radix/sonner) · [React Aria](https://ui.shadcn.com/docs/components/aria/accordion) · [67 项截图索引](Images/Shadcn/README.md)

## 在画廊中查看

打开 **shadcn/ui** 分组，或搜索 `Accordion`、`Data Table`、`Questionnaire` 等名称。Apple 画廊也支持 `swift run AIElementsGallery --shadcn calendar`。同名的 AI Elements 模式和流式节点保留原入口。命令行可用 `./aielements example shadcn-message` 精确选择组件。

| 原生库 | 可用平台 | 画廊 |
| --- | --- | --- |
| SwiftUI，`AIElements` | iOS / iPadOS 17+、macOS 14+ | [Swift 仓库入口](../Sources/AIElementsGallery/GalleryApp.swift) |
| Kotlin，`dev.aielements.compose` | Android API 26+ | [Android 工程](../Android/README.md) |
| ArkTS，`@aielements/arkui` | HarmonyOS NEXT API 12+ | [HarmonyOS 工程](../HarmonyOS/README.md) |

## 嵌入组件

下面的复选框使用同一个稳定 ID。交互后，三端都向宿主报告 `terms` 和字符串值 `true` 或 `false`。

**SwiftUI**

```swift
import AIElements
import SwiftUI

struct TermsView: View {
    @State private var values: [String: String] = [:]

    var body: some View {
        AIShadcnView(
            .init(.checkbox, "Accept terms", id: "terms"),
            values: $values,
            onAction: { id, value in print(id, value) }
        )
    }
}
```

**Jetpack Compose**

```kotlin
@Composable
fun Terms() {
    val state = rememberAIShadcnState()
    AIElementsTheme {
        AIShadcnView(
            node = AIShadcnNode(AIShadcnKind.Checkbox, id = "terms", label = "Accept terms"),
            state = state
        ) { id, value -> Log.d("Terms", "$id=$value") }
    }
}
```

**ArkUI**

```typescript
import { AIShadcnState, AIShadcnView } from '@aielements/arkui';

@Component
struct Terms {
  @State private values: AIShadcnState = new AIShadcnState();

  build() {
    AIShadcnView({
      node: { kind: 'checkbox', id: 'terms', label: 'Accept terms' },
      state: this.values,
      onAction: (id: string, value: string) => console.info(id + '=' + value)
    })
  }
}
```

`AIShadcnNode` 的 `children` 支持组合视图，`items` 提供选项与稳定 ID，`columns` 和 `rows` 提供图表或表格数据。表单由宿主注入状态，也可直接使用本地状态。重新排序的交互子节点应提供显式 ID。数据表支持筛选、排序、分页和部分选中。宿主会刷新或重排数据时，传入与 `rows` 一一对应的 `rowIDs`，选中项和详情回调便按业务 ID 定位。整组 ID 须非空且唯一，缺省或无效时沿用原有行号。可用从零开始的 `filterColumn` 指定筛选列，缺省时搜索全部单元格。官方付款示例只筛选邮箱列。图片可通过 SwiftUI 的 `images` 闭包、Compose 的 `Painter` 解析器或 ArkUI 的资源映射提供。

完整示例可以从 Swift 的 `AIShadcnCatalog.examples`、Android 的 `AIShadcnCatalog.examples(context)` 和 ArkUI 的 `loadAIShadcnCatalog()` 获取。Swift 和 Android 直接读取共享 JSON，ArkUI 将同一份数据编进 HAR，可在设备和 SDK Previewer 离线使用。更新样例后运行 `python3 HarmonyOS/sync-fixtures.py`。[共享示例文件](../Sources/AIElementsCatalog/Resources/shadcn-catalog.json)

## 如何看视觉对照

每张图固定为六列，上排浅色、下排深色。浏览器为 360 CSS px，Apple 为 360 pt，Compose 为 360 dp，ArkUI 为 360 vp。原始像素按设备密度换算，没有逐个缩放组件以凑齐高度。列头显示该示例的实际画布高度。对照图按每行最高的画布居中排版。[全部图片](Images/Shadcn/README.md)

| 列 | 渲染来源 |
| --- | --- |
| shadcn/ui | Chromium 运行官网文档中的示例，保留上游 DOM、CSS、字体与示例初始状态 |
| macOS | 本机 AppKit `NSHostingView` 渲染 SwiftUI |
| iPhone、iPad | 两台独立的 iOS 27 模拟器中运行同一个 Gallery，使用 UIKit 宿主绘制 |
| Android | Android 15（API 35）模拟器中的 Compose instrumentation 截图 |
| HarmonyOS | OpenHarmony API 12 SDK Previewer 运行 ArkUI 字节码，读取引擎输出的图像帧 |

每项选一个有代表性的状态，去掉官网文档外框和留白。Sidebar 采集 Projects 分组，Message Scroller 采集 Reading Scroll State 的消息视口，Typography 采集 H3，Chart 采集柱状图。Avatar 在官方图片槽加载后截取，GitHub 头像请求使用该示例随库提供的灰度素材。截图范围覆盖组件目录的具名示例，其他视觉预设、Blocks 页面和其余变体仍待单独比对。[Sidebar](https://ui.shadcn.com/view/base-nova/sidebar-demo) · [Message Scroller](https://ui.shadcn.com/docs/components/base/message-scroller#reading-scroll-state) · [Typography](https://ui.shadcn.com/view/new-york-v4/typography-h3) · [Chart](https://ui.shadcn.com/view/new-york-v4/chart-bar-default)

在 360 逻辑单位宽的浅色示例中，Code Block 的官网画布高 260 px，各原生端为 259 至 262 个逻辑单位。Radio Group 的官网画布高 64 px，iPhone 和 iPad 的默认密度各占 132 pt，三个选项分别保留 44 pt 触控高度。宿主可用 `.aiControlDensity(.reference)` 选用紧凑布局。同样宽度下，官网 Navigation Menu 的两端被裁切，移动端会将 Docs 换到下一行，保留完整入口。各端的菜单、键盘、焦点和字形栅格也由原生系统参与绘制。[Code Block 对照](Images/Shadcn/code-block.webp) · [Radio Group 对照](Images/Shadcn/radio-group.webp) · [Navigation Menu 对照](Images/Shadcn/navigation-menu.webp)

鸿蒙 SDK 12 Previewer 在 `-cm dark` 下仍读取应用的默认色值。深色截图使用同一份 ArkUI 字节码，在预览包中显式加载仓库的 `dark/element` 资源。导出器核对资源 ID 和引擎实际画布颜色，设备 HAP 保留系统浅深资源限定符。本次鸿蒙验证使用 SDK Previewer，真机效果尚待验收。

`measurements.json` 中的 `foregroundMeanAbsoluteRGB` 是官网与原生图在前景并集上的 RGB 平均绝对差，单位为 0 至 255 的色阶。比较先对齐同宽画布，再排除双方都是背景的像素。字形、折行、行高及内容位置变化都会增加这个数值。原生端有可见差异，验收记录未将其认定为逐像素相同。[测量数据](Images/Shadcn/measurements.json)

## 本轮审查与修复

对照覆盖 67 个条目的默认浅深色示例，并单独复测了状态变化最容易影响数据或操作的路径。下表采用同宽、浅色示例的逻辑高度。原始截图和前景色差按组件与平台列在索引中。[全部对照](Images/Shadcn/README.md)

| 示例与平台 | 官网 | 修复前 | 修复后 | 可观察的变化 |
| --- | ---: | ---: | ---: | --- |
| Radio Group · iPhone / iPad | 64 | 156 | 132 | 去掉触控行之间重复的间距，三个选项各保留 44 pt |
| Radio Group · HarmonyOS | 64 | 72 | 64 | 三行采用官网的 8 vp 间隔 |
| Message · HarmonyOS | 197 | 168 | 197 | 消息头、气泡和已读信息恢复对应的行高、内缩和间距 |
| Table · HarmonyOS | 372 | 340 | 372 | 在 360 vp 宽度内同时显示四列，金额和合计可直接读取 |
| Data Table · HarmonyOS | 371 | 335 | 371 | 恢复筛选栏和分页栏的内缩与间距 |
| Chart · HarmonyOS | 355 | 393 | 353 | 图区随宽度缩放，点按选取数据，长按查看数据清单，读屏有逐行入口 |

SwiftUI 图表曾在两列同名时因重复字典键崩溃。现在按列保留独立的数据系列。三端的数据表支持用业务 ID 跟踪选中行，付款示例只搜索邮箱列。禁用选项和已移除的答案不能再让问卷通过验证。返回上一步会保留答案，点“Start again”会恢复该问卷的初始值。Swift 接入文档中的完整示例也纳入了 CLI 的宿主编译检查。[官方付款示例](https://ui.shadcn.com/docs/components/base/data-table) · [问卷对照](Images/Shadcn/questionnaire.webp)

鸿蒙的线性图标改为从 Lucide 笔画生成可着色的轮廓路径，勾选框、圆圈和图标内孔在浅深色下都保留原形。加载指示器使用同一枚缺口圆环，截图固定旋转角度。按钮组、面包屑和标签页按内容确定宽度，空间不足时换行。官网进度条会从 13% 变为 66%，采集器等到 66% 再与同一数值的原生示例比较。[加载指示器](Images/Shadcn/spinner.webp) · [进度条](Images/Shadcn/progress.webp) · [按钮组](Images/Shadcn/button-group.webp)

## 已执行的交互验证

iPhone 模拟器的 6 项 XCUITest 覆盖弹窗、问卷、轮播、Sonner 撤销、邮箱筛选以及单选行边缘的真实点按。Android 的 7 项组件 instrumentation 测试覆盖全部 67 项的浅深色渲染，另验证了部分选中、宿主重排和改名后的行选中状态、无效问卷答案、重新开始及独立通知的自动消失。鸿蒙的 9 项数据与布局回归包含稳定行 ID、重复行、缺失单元格及按列筛选，SDK Previewer 执行 ArkUI 字节码检查各组件的实际输出。[iPhone 弹窗打开态](Images/Shadcn-dialog-open-ios.webp) · [iPhone 问卷选中态](Images/Shadcn-questionnaire-selected-ios.webp)

## 复现

- **官网**安装 Playwright 和 Chromium 后运行 `node Scripts/capture-shadcn.mjs`。可通过 `PLAYWRIGHT_PATH` 和 `CHROMIUM_PATH` 指定已有安装。可指定输出目录和需要重采的 slug。
- **macOS** 运行 `swift run AIElementsGallery --shadcn-snapshots --output .build/shadcn-audit/mac`。
- **iPhone / iPad** 构建并安装 `Examples/AIElementsDemo.xcodeproj` 中的 `AIElementsDemo`，以 `--shadcn-snapshots` 启动，导出 App 数据容器内 `Documents/shadcn-audit` 的 PNG，分别放入 `.build/shadcn-audit/ios` 和 `.build/shadcn-audit/ipad`。运行该 scheme 的 UI tests 可以验证弹窗、问卷、轮播、Sonner 撤销、数据筛选和单选命中区。
- **Android** 在 Android 工程运行 `./gradlew :aielements:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=dev.aielements.compose.ShadcnCatalogTest -Pandroid.testInstrumentationRunnerArguments.shadcnSnapshots=true`。用 adb 拉取 `/sdcard/Download/AIElementsShadcn/.` 到 `.build/shadcn-audit/android`。
- **HarmonyOS** 用 API 12 工具链构建 gallery。将 Previewer 可执行文件、包含 `modules.abc` 的目录、包含 `module.json` 和 `resources.index` 的合并资源目录传给 `python3 Scripts/capture-shadcn-harmony.py --previewer … --ets … --resources … --dark-resource-compiler /path/to/restool`。该脚本需安装 Pillow 和 websocket-client，通过本机回环连接引擎。
- **合成** 安装 Pillow 11+ 后运行 `python3 Scripts/compare-shadcn.py`，检查 804 个输入并重新生成 67 张无损 WebP 和尺寸、色差记录。
