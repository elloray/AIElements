@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)

package dev.aielements.compose

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.*
import dev.aielements.compose.AIShadcnKind.*

private val LocalShadcnImages = staticCompositionLocalOf<(String) -> Painter?> { { null } }

@Composable
fun AIShadcnView(
    node: AIShadcnNode,
    modifier: Modifier = Modifier,
    state: AIShadcnState = rememberAIShadcnState(),
    images: (String) -> Painter? = { null },
    onAction: (String, String) -> Unit = { _, _ -> },
) {
    CompositionLocalProvider(LocalShadcnImages provides images) {
        ShadcnPart(node, node.id ?: node.kind.slug, state, onAction).Render(modifier)
    }
}

internal class ShadcnPart(
    val node: AIShadcnNode,
    val path: String,
    val state: AIShadcnState,
    val action: (String, String) -> Unit,
) {
    val value
        get() = state.values[path] ?: node.value

    fun set(value: String) {
        state.values[path] = value
        action(path, value)
    }

    fun press(label: String) {
        action(path, label)
    }

    fun child(index: Int): ShadcnPart {
        val child = node.children[index]
        return ShadcnPart(child, child.id ?: "$path/$index", state, action)
    }

    @Composable
    fun Children() {
        node.children.forEachIndexed { i, c -> key(c.id ?: i) { child(i).Render() } }
    }
}

internal fun Modifier.panel(fill: Color, border: Color, radius: Int = 10): Modifier {
    val shape = RoundedCornerShape(radius.dp)
    return clip(shape)
        .background(fill)
        .then(if (border == Color.Transparent) Modifier else Modifier.border(1.dp, border, shape))
}

@Composable
internal fun Caption(
    text: String,
    size: Int = 14,
    bold: Boolean = false,
    muted: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val colors = AITheme.colors
    Text(
        text,
        modifier,
        color = if (muted) colors.mutedForeground else colors.foreground,
        style =
            AITypography.body.copy(
                fontSize = size.sp,
                lineHeight = (size * 1.4f).sp,
                fontWeight = if (bold) FontWeight.Medium else FontWeight.Normal,
            ),
    )
}

internal fun glyph(name: String?) =
    AIIconName.entries.firstOrNull {
        it.name.equals(name.orEmpty().replace("-", ""), ignoreCase = true)
    } ?: AIIconName.circle

@Composable
internal fun ShadcnPart.Render(modifier: Modifier = Modifier) {
    key(path, node.kind) { RenderNode(modifier) }
}

@Composable
private fun ShadcnPart.RenderNode(modifier: Modifier) {
    val c = AITheme.colors
    val sized = node.width?.let { Modifier.widthIn(max = it.dp).fillMaxWidth() } ?: Modifier
    Box(modifier.then(sized)) {
        when (node.kind) {
            Column ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(node.gap.dp),
                    horizontalAlignment =
                        if (node.align == "center") Alignment.CenterHorizontally
                        else Alignment.Start,
                ) {
                    Children()
                }
            Row ->
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(node.gap.dp),
                    verticalArrangement = Arrangement.spacedBy(node.gap.dp),
                    itemVerticalAlignment = Alignment.CenterVertically,
                ) {
                    Children()
                }
            AIShadcnKind.Text,
            Typography ->
                Caption(
                    node.label,
                    when (node.variant) {
                        "h1" -> 36
                        "h2" -> 30
                        "h3" -> 24
                        "h4",
                        "lead" -> 20
                        "large" -> 18
                        else -> 14
                    },
                    node.variant in listOf("label", "semibold", "h1", "h2", "h3", "h4", "large"),
                    node.variant in listOf("muted", "lead"),
                )
            Image -> SampleImage(node.value, node.label, Modifier.fillMaxSize())
            AspectRatio ->
                Box(
                    Modifier.fillMaxWidth()
                        .aspectRatio(value.toFloatOrNull()?.takeIf { it > 0f } ?: (16f / 9))
                        .clip(RoundedCornerShape(10.dp))
                ) {
                    Children()
                }
            Avatar ->
                Box(
                    Modifier.size((node.size ?: 32f).dp).clip(CircleShape).background(c.muted),
                    contentAlignment = Alignment.Center,
                ) {
                    Caption(value, bold = true)
                    node.asset?.let { SampleImage(it, node.label, Modifier.fillMaxSize()) }
                }
            Accordion,
            Collapsible -> Disclosure()
            Alert,
            Attachment,
            Item -> Information()
            Badge -> AIBadge(node.label, node.variant.ifEmpty { "primary" })
            Breadcrumb,
            ButtonGroup,
            ToggleGroup,
            Pagination,
            Tabs -> Segmented()
            Bubble,
            Message,
            Marker -> MessageContent()
            Button ->
                AIButton(
                    node.label,
                    variant = node.variant.ifEmpty { "primary" },
                    capsule = false,
                ) {
                    press(node.label)
                }
            Calendar -> CalendarPage()
            Card ->
                AICard(
                    title = node.label,
                    description = node.detail,
                    headerAction =
                        node.action?.let { title ->
                            { AIButton(title, variant = "ghost") { press(title) } }
                        },
                    footerContent =
                        if (node.items.isEmpty()) null
                        else {
                            {
                                node.items.forEachIndexed { i, item ->
                                    AIButton(
                                        item.label,
                                        Modifier.fillMaxWidth(),
                                        variant = if (i == 0) "primary" else "outline",
                                        enabled = !item.disabled,
                                        capsule = false,
                                    ) {
                                        press(item.key)
                                    }
                                }
                            }
                        },
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) { Children() }
                }
            Carousel -> CarouselPanel()
            Chart -> ChartPanel()
            CodeBlock ->
                if (node.action != null)
                    AICodeBlock(value, showCopy = true, showLineNumbers = false)
                else
                    SelectionContainer {
                        Column(
                            Modifier.fillMaxWidth()
                                .panel(c.muted, Color.Transparent, 14)
                                .horizontalScroll(rememberScrollState())
                                .padding(16.dp)
                        ) {
                            value.lines().forEach { line ->
                                Box(
                                    Modifier.heightIn(min = 22.75.dp),
                                    contentAlignment = Alignment.CenterStart,
                                ) {
                                    Text(
                                        line.ifEmpty { " " },
                                        fontFamily = AITypography.mono,
                                        fontSize = 14.sp,
                                        color = c.foreground,
                                        softWrap = false,
                                    )
                                }
                            }
                        }
                    }
            Combobox,
            Command,
            ContextMenu,
            DropdownMenu,
            NativeSelect,
            Select -> Choice()
            AlertDialog,
            DatePicker,
            Dialog,
            Drawer,
            HoverCard,
            Popover,
            Sheet,
            Toast,
            Tooltip -> Overlay()
            Sonner -> SonnerPanel()
            Direction ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    horizontalAlignment = Alignment.End,
                ) {
                    val index = node.items.indexOfFirst { it.key == value }.coerceAtLeast(0)
                    val language = node.items.getOrNull(index)
                    var choosing by remember { mutableStateOf(false) }
                    if (node.variant == "picker" && language != null)
                        Box {
                            AIButton(
                                language.label,
                                variant = "ghost",
                                compact = true,
                                capsule = false,
                            ) {
                                choosing = true
                            }
                            androidx.compose.material3.DropdownMenu(
                                choosing,
                                { choosing = false },
                                containerColor = c.card,
                            ) {
                                node.items.forEach { item ->
                                    androidx.compose.material3.DropdownMenuItem(
                                        text = { Caption(item.label) },
                                        onClick = {
                                            set(item.key)
                                            choosing = false
                                        },
                                    )
                                }
                            }
                        }
                    CompositionLocalProvider(
                        LocalLayoutDirection provides
                            if ((language?.detail ?: value) == "rtl") LayoutDirection.Rtl
                            else LayoutDirection.Ltr
                    ) {
                        if (language != null && index in node.children.indices)
                            child(index).Render()
                        else Children()
                    }
                }
            Empty ->
                Column(
                    Modifier.fillMaxWidth().panel(c.background, c.border, 14).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    node.icon?.let {
                        Box(
                            Modifier.size(40.dp).panel(c.muted, Color.Transparent),
                            contentAlignment = Alignment.Center,
                        ) {
                            AIIcon(glyph(it), Modifier.size(24.dp), c.foreground)
                        }
                    }
                    Caption(node.label, 18, true)
                    Caption(node.detail, muted = true)
                    Children()
                    node.action?.let {
                        AIButton(it, variant = "outline", capsule = false) { press(it) }
                    }
                }
            Checkbox,
            Field,
            Input,
            InputGroup,
            InputOtp,
            Label,
            RadioGroup,
            Slider,
            Textarea,
            Toggle -> Form()
            Kbd ->
                Box(
                    Modifier.defaultMinSize(minWidth = 20.dp, minHeight = 20.dp)
                        .panel(c.muted, Color.Transparent, 5)
                        .padding(horizontal = 4.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Caption(node.label, 12, true, true)
                }
            Menubar,
            NavigationMenu,
            Sidebar -> Navigation()
            MessageScroller -> Scroller()
            Progress -> AIProgress(value.toFloatOrNull() ?: 0f)
            Questionnaire -> QuestionnairePanel()
            Resizable -> ResizablePanel()
            ScrollArea ->
                Column(
                    Modifier.fillMaxWidth()
                        .height((node.height ?: 288f).dp)
                        .panel(c.background, c.border, 8)
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp)
                ) {
                    if (node.label.isNotEmpty()) {
                        Caption(node.label, bold = true)
                        Spacer(Modifier.height(16.dp))
                    }
                    node.items.forEach {
                        Caption(it.label)
                        Spacer(Modifier.height(8.dp))
                        AISeparator()
                        Spacer(Modifier.height(8.dp))
                    }
                    Children()
                }
            Separator -> AISeparator()
            Skeleton -> SkeletonShape()
            Spinner -> SpinningIcon()
            Switch -> AISwitch(value == "true", { set(it.toString()) }, node.label)
            Table,
            DataTable -> TablePanel()
            Trace -> AITraceLine(node.label, icon = glyph(node.icon))
        }
    }
}

@Composable
private fun SampleImage(asset: String, label: String, modifier: Modifier) {
    val painter =
        LocalShadcnImages.current(asset)
            ?: when (asset) {
                "shadcn-avatar" -> painterResource(R.drawable.aie_shadcn_avatar)
                "shadcn-aspect" -> painterResource(R.drawable.aie_shadcn_aspect)
                else -> return
            }
    val brightness = if (asset == "shadcn-aspect" && AITheme.colors.dark) .2f else 1f
    Image(
        painter,
        label,
        modifier,
        contentScale = ContentScale.Crop,
        colorFilter =
            ColorFilter.colorMatrix(
                ColorMatrix().apply { setToScale(brightness, brightness, brightness, 1f) }
            ),
    )
}

@Composable
private fun ShadcnPart.Disclosure() {
    val c = AITheme.colors
    if (node.kind == Collapsible) {
        Column(
            Modifier.fillMaxWidth().panel(c.card, c.border, 14).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                Modifier.fillMaxWidth()
                    .clickable { set((value != "true").toString()) }
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Caption(node.label, bold = true, modifier = Modifier.weight(1f))
                AIIcon(AIIconName.chevronDown, Modifier.rotate(if (value == "true") 180f else 0f))
            }
            if (value == "true") {
                Caption(node.detail)
                Children()
                node.action?.let { AIButton(it, capsule = false) { press(it) } }
            }
        }
    } else
        Column {
            node.items.forEachIndexed { index, item ->
                Row(
                    Modifier.fillMaxWidth()
                        .clickable(enabled = !item.disabled, role = Role.Button) {
                            set(if (value == item.key) "" else item.key)
                        }
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Caption(item.label, bold = true, modifier = Modifier.weight(1f))
                    AIIcon(
                        AIIconName.chevronDown,
                        Modifier.rotate(if (value == item.key) 180f else 0f),
                    )
                }
                if (value == item.key)
                    Caption(item.detail, modifier = Modifier.padding(bottom = 12.dp))
                if (index < node.items.lastIndex) AISeparator()
            }
        }
}

@Composable
private fun ShadcnPart.Information() {
    val c = AITheme.colors
    val attachment = node.kind == Attachment
    val small = node.variant in listOf("sm", "xs")
    Row(
        Modifier.fillMaxWidth()
            .panel(if (node.kind == Alert) c.card else c.background, c.border, 12)
            .padding(if (attachment) (if (small) 5 else 8).dp else 12.dp),
        verticalAlignment = if (node.kind == Alert) Alignment.Top else Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (attachment) 8.dp else 12.dp),
    ) {
        node.icon?.let { name ->
            if (attachment)
                Box(
                    Modifier.size(if (small) 28.dp else 36.dp).panel(c.muted, Color.Transparent, 6),
                    contentAlignment = Alignment.Center,
                ) {
                    AIIcon(glyph(name), color = c.foreground)
                }
            else AIIcon(glyph(name), color = c.foreground)
        }
        Column(
            Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(if (attachment) 1.dp else 4.dp),
        ) {
            Caption(node.label, if (attachment && small) 12 else 14, true)
            if (node.detail.isNotEmpty())
                Caption(node.detail, if (attachment) 12 else 14, muted = true)
            Children()
        }
        node.action?.let {
            AIButton(it, variant = "outline", capsule = false, compact = true) { press(it) }
        }
        if (node.variant == "link")
            AIIconButton(AIIconName.chevronRight, node.label) { press(node.label) }
    }
}

@Composable
private fun ShadcnPart.MessageContent() {
    val c = AITheme.colors
    val end = node.align == "end"
    when (node.kind) {
        Marker ->
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (node.variant == "separator") AISeparator(Modifier.weight(1f))
                Caption(node.label, 14, muted = true)
                if (node.variant == "separator") AISeparator(Modifier.weight(1f))
            }
        Message ->
            Column(
                Modifier.fillMaxWidth(),
                horizontalAlignment = if (end) Alignment.End else Alignment.Start,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (node.label.isNotBlank())
                    Caption(node.label, 12, true, true, Modifier.padding(horizontal = 12.dp))
                Children()
                if (node.detail.isNotBlank())
                    Caption(
                        node.detail,
                        12,
                        muted = true,
                        modifier = Modifier.padding(horizontal = 12.dp),
                    )
            }
        else ->
            Box(
                Modifier.fillMaxWidth(),
                contentAlignment = if (end) Alignment.CenterEnd else Alignment.CenterStart,
            ) {
                val muted = node.variant in listOf("muted", "secondary")
                val ghost = node.variant == "ghost"
                val fill =
                    if (ghost) Color.Transparent
                    else if (muted) c.muted
                    else if (c.dark) Color(0xFF193CB8) else Color(0xFF1447E6)
                Box(
                    Modifier.fillMaxWidth(if (ghost) 1f else .8f),
                    contentAlignment = if (end) Alignment.CenterEnd else Alignment.CenterStart,
                ) {
                    Text(
                        node.label,
                        Modifier.panel(fill, Color.Transparent, 24)
                            .padding(
                                horizontal = if (ghost) 0.dp else 13.dp,
                                vertical = if (ghost) 0.dp else 11.dp,
                            ),
                        style =
                            AITypography.body.copy(
                                lineHeight = 22.75.sp,
                                lineHeightStyle =
                                    LineHeightStyle(
                                        LineHeightStyle.Alignment.Center,
                                        LineHeightStyle.Trim.None,
                                    ),
                            ),
                        color = if (muted || ghost) c.foreground else Color.White,
                    )
                }
            }
    }
}
