@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package dev.aielements.compose

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
import java.net.URI

/** Common Markdown blocks; deliberately no executable HTML, remote image loading or expression evaluation. */
@Composable fun AIMessageResponse(text: String, modifier: Modifier = Modifier, muted: Boolean = false) {
    val traceContent = LocalAITraceContent.current
    val body = if (LocalAIMessageUser.current || traceContent) AITypography.body.copy(lineHeight = 22.75.sp) else AITypography.body
    val paragraphGap = if (traceContent) with(androidx.compose.ui.platform.LocalDensity.current) { 22.75.sp.toDp() } else 16.dp
    Column(modifier, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        val parts = text.split("```")
        parts.forEachIndexed { index, part ->
            if (index % 2 == 1) AICodeBlock(part.substringAfter('\n', ""), part.substringBefore('\n'))
            else if (part.isNotBlank()) SelectionContainer {
                Column(verticalArrangement = Arrangement.spacedBy(paragraphGap)) {
                    part.trim().split(Regex("\\n\\s*\\n")).forEach { paragraph ->
                        val heading = paragraph.takeWhile { it == '#' }.length.takeIf { it in 1..6 && paragraph.getOrNull(it) == ' ' } ?: 0
                        val value = if (heading > 0) paragraph.drop(heading + 1) else paragraph
                        MarkdownText(value, color = if (muted) AITheme.colors.mutedForeground else AITheme.colors.foreground,
                            style = if (heading > 0) AITypography.title.copy(fontSize = (26 - heading * 2).coerceAtLeast(16).sp) else body)
                    }
                }
            }
        }
    }
}
@Composable private fun MarkdownText(value: String, color: Color, style: TextStyle) {
    val c = AITheme.colors; val measurer = rememberTextMeasurer()
    val density = androidx.compose.ui.platform.LocalDensity.current
    BoxWithConstraints {
        val codeStyle = style.copy(fontFamily = AITypography.mono, fontSize = style.fontSize * .9f, lineHeight = style.lineHeight * .9f)
        val inline = mutableMapOf<String, androidx.compose.foundation.text.InlineTextContent>()
        val annotated = buildAnnotatedString {
            val pattern = Regex("\\*\\*(.+?)\\*\\*|`([^`]+)`|\\[([^]]+)]\\((https?://[^)]+)\\)")
            var cursor = 0
            pattern.findAll(value).forEach { m ->
                append(value.substring(cursor, m.range.first))
                when {
                    m.groupValues[1].isNotEmpty() -> withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append(m.groupValues[1]) }
                    m.groupValues[2].isNotEmpty() -> {
                        val code = m.groupValues[2]
                        val width = with(density) { measurer.measure(code, codeStyle, softWrap = false).size.width.toDp() + 8.dp }
                        if (width <= maxWidth) {
                            val id = "code-${m.range.first}"
                            inline[id] = androidx.compose.foundation.text.InlineTextContent(Placeholder(with(density) { width.toSp() }, style.lineHeight, PlaceholderVerticalAlign.TextCenter)) {
                                Box(Modifier.fillMaxSize().background(c.muted, RoundedCornerShape(6.dp)), contentAlignment = Alignment.Center) {
                                    Text(code, color = color, style = codeStyle, maxLines = 1)
                                }
                            }
                            // Alternative text preserves the real code for selection and accessibility.
                            appendInlineContent(id, code)
                        } else withStyle(SpanStyle(fontFamily = AITypography.mono, fontSize = codeStyle.fontSize, background = c.muted)) { append(code) }
                    }
                    else -> withLink(LinkAnnotation.Url(m.groupValues[4])) { append(m.groupValues[3]) }
                }
                cursor = m.range.last + 1
            }
            append(value.substring(cursor))
        }
        Text(annotated, inlineContent = inline, color = color, style = style)
    }
}
data class AIFileNode(val path: String, val children: List<AIFileNode>? = null) { val name: String get() = path.substringAfterLast('/') }
@Composable fun AIFileTree(nodes: List<AIFileNode>, selection: String? = null, modifier: Modifier = Modifier,
    expandedPaths: Set<String>? = null, onExpandedPathsChange: ((Set<String>) -> Unit)? = null, onSelect: (AIFileNode) -> Unit = {}) {
    var saved by rememberSaveable { mutableStateOf(emptyList<String>()) }
    val expanded = expandedPaths ?: saved.toSet()
    fun toggle(path: String) { val next = if (path in expanded) expanded - path else expanded + path; if (expandedPaths == null) saved = next.toList(); onExpandedPathsChange?.invoke(next) }
    Column(modifier) {
        @Composable fun Node(node: AIFileNode, depth: Int) {
            key(node.path) {
                Box(Modifier.fillMaxWidth().padding(start = (depth * 16).dp).heightIn(min = 48.dp)
                    .clickable(role = Role.Button) { if (node.children != null) toggle(node.path) else onSelect(node) }
                    .semantics { selected = node.path == selection; if (node.children != null) stateDescription = if (node.path in expanded) "Expanded" else "Collapsed" }, contentAlignment = Alignment.CenterStart) {
                    Row(Modifier.fillMaxWidth().heightIn(min = 28.dp).background(if (node.path == selection) (if (AITheme.colors.dark) AITheme.colors.accent else Color(0xFFF0F0F0)) else Color.Transparent, RoundedCornerShape(50))
                        .padding(horizontal = 13.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        if (node.children != null) AIIcon(if (node.path in expanded) AIIconName.chevronDown else AIIconName.chevronRight, color = AITheme.colors.foreground)
                        AIIcon(if (node.children == null) AIIconName.file else AIIconName.folder, color = AITheme.colors.foreground)
                        AIText(node.name, Modifier.weight(1f))
                    }
                }
                if (node.path in expanded) node.children?.forEach { Node(it, depth + 1) }
            }
        }
        nodes.forEach { Node(it, 0) }
    }
}
data class AISource(val title: String, val url: String, val summary: String = "")
private fun safeWebUrl(url: String): Boolean = runCatching { val u = URI(url); u.scheme in listOf("https", "http") && !u.host.isNullOrEmpty() }.getOrDefault(false)
@Composable fun AISources(sources: List<AISource>, modifier: Modifier = Modifier) {
    val uri = LocalUriHandler.current
    AITraceDisclosure("Used ${sources.size} sources", modifier, initiallyExpanded = true, icon = AIIconName.globe, contentSpacing = 0.dp) {
        sources.forEach { source ->
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(enabled = safeWebUrl(source.url), role = Role.Button) { uri.openUri(source.url) },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                AIText(source.title, Modifier.weight(1f, fill = false), muted = true); AIIcon(AIIconName.arrowUpRight)
            }
        }
    }
}
private fun citationLabel(sources: List<AISource>): String {
    val first = sources.firstOrNull() ?: return "Source"
    return (runCatching { URI(first.url).host?.removePrefix("www.") }.getOrNull() ?: first.title) + if (sources.size > 1) " +${sources.size - 1}" else ""
}
@Composable private fun SourceDialog(sources: List<AISource>, onDismiss: () -> Unit) {
    if (sources.isEmpty()) return
    var page by rememberSaveable { mutableIntStateOf(0) }; val source = sources[page.coerceIn(sources.indices)]; val uri = LocalUriHandler.current
    AlertDialog(onDismissRequest = onDismiss, title = { AIText(source.title, variant = "title") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (source.summary.isNotEmpty()) AIText(source.summary)
            AIText(source.url, muted = true)
            if (sources.size > 1) Row(verticalAlignment = Alignment.CenterVertically) {
                AIIconButton(AIIconName.chevronRight, "Previous source", Modifier.rotate(180f), enabled = page > 0) { page-- }
                AIText("${page + 1}/${sources.size}")
                AIIconButton(AIIconName.chevronRight, "Next source", enabled = page < sources.lastIndex) { page++ }
            }
        }
    }, confirmButton = { AIButton("Open source", enabled = safeWebUrl(source.url)) { uri.openUri(source.url) } }, dismissButton = { AIButton("Close", variant = "ghost", onClick = onDismiss) })
}
@Composable fun AIInlineCitation(sources: List<AISource>, modifier: Modifier = Modifier) {
    var open by rememberSaveable { mutableStateOf(false) }
    if (sources.isNotEmpty()) {
        AIButton(citationLabel(sources), modifier, "secondary") { open = true }
        if (open) SourceDialog(sources) { open = false }
    }
}
sealed interface AICitedPart { data class Text(val text: String) : AICitedPart; data class Citation(val sources: List<AISource>) : AICitedPart }
/** Embedded inline content participates in the paragraph's line breaker, never a FlowRow. */
@Composable fun AICitedText(parts: List<AICitedPart>, modifier: Modifier = Modifier) {
    var active by rememberSaveable { mutableIntStateOf(-1) }
    val c = AITheme.colors; val measurer = rememberTextMeasurer(); val density = androidx.compose.ui.platform.LocalDensity.current
    val inline = mutableMapOf<String, androidx.compose.foundation.text.InlineTextContent>()
    val citationStyle = AITypography.caption.copy(fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium)
    val paragraphs = mutableListOf<AnnotatedString>()
    var builder = AnnotatedString.Builder()
    with(builder) {
        parts.forEachIndexed { index, part -> when (part) {
            is AICitedPart.Text -> part.text.split("\n\n").forEachIndexed { partIndex, value ->
                if (partIndex > 0) { paragraphs += builder.toAnnotatedString(); builder = AnnotatedString.Builder() }
                builder.append(value)
            }
            is AICitedPart.Citation -> if (part.sources.isNotEmpty()) {
                val label = citationLabel(part.sources); val id = "citation-$index"
                val width = with(density) { (measurer.measure(label, citationStyle).size.width.toDp() + 22.dp).toSp() }
                inline[id] = androidx.compose.foundation.text.InlineTextContent(Placeholder(width, 24.sp, PlaceholderVerticalAlign.TextCenter)) {
                    Box(Modifier.fillMaxSize().background(c.muted, RoundedCornerShape(50)).clickable(role = Role.Button) { active = index }
                        .semantics { contentDescription = "Sources: $label" }, contentAlignment = Alignment.Center) {
                        Text(label, color = c.foreground, style = citationStyle, maxLines = 1)
                    }
                }
                builder.appendInlineContent(id, label)
            }
        } }
    }
    paragraphs += builder.toAnnotatedString()
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        paragraphs.forEach { paragraph -> Text(paragraph, inlineContent = inline, color = c.foreground, style = AITypography.body.copy(lineHeight = 22.75.sp)) }
    }
    (parts.getOrNull(active) as? AICitedPart.Citation)?.let { part -> key(active) { SourceDialog(part.sources) { active = -1 } } }
}
@Composable fun AISuggestion(text: String, onSelect: (String) -> Unit) { AIButton(text, variant = "outline") { onSelect(text) } }
@Composable fun AISuggestions(suggestions: List<String>, modifier: Modifier = Modifier, onSelect: (String) -> Unit) {
    val scroll = rememberScrollState(); val background = AITheme.colors.background
    Row(modifier.drawWithContent {
        drawContent()
        if (scroll.canScrollForward) drawRect(Brush.horizontalGradient(listOf(Color.Transparent, background), startX = (size.width - 24.dp.toPx()).coerceAtLeast(0f), endX = size.width))
        if (scroll.canScrollBackward) drawRect(Brush.horizontalGradient(listOf(background, Color.Transparent), startX = 0f, endX = 24.dp.toPx()))
    }.horizontalScroll(scroll), horizontalArrangement = Arrangement.spacedBy(8.dp)) { suggestions.forEach { AISuggestion(it, onSelect) } }
}
data class AIModel(val id: String, val name: String, val provider: String)
@Composable fun AIModelSelector(models: List<AIModel>, selectedID: String, onSelect: (String) -> Unit, modifier: Modifier = Modifier, effort: String? = null, onEffortChange: ((String) -> Unit)? = null) {
    var open by rememberSaveable { mutableStateOf(false) }
    var effortOpen by rememberSaveable { mutableStateOf(false) }
    FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box {
            AIButton(models.firstOrNull { it.id == selectedID }?.name ?: "Select model", variant = "menu", trailingIcon = AIIconName.chevronDown) { open = true }
            DropdownMenu(open, { open = false }) {
                models.groupBy { it.provider }.forEach { (provider, group) ->
                    AIText(provider, Modifier.padding(12.dp), muted = true, variant = "caption")
                    group.forEach { model -> DropdownMenuItem({ AIText(model.name) }, { onSelect(model.id); open = false }, trailingIcon = { if (selectedID == model.id) AIIcon(AIIconName.check) }) }
                }
            }
        }
        if (effort != null && onEffortChange != null) Box {
            AIButton("Effort  $effort", variant = "menu", trailingIcon = AIIconName.chevronDown) { effortOpen = true }
            DropdownMenu(effortOpen, { effortOpen = false }) { listOf("Low", "Medium", "High").forEach { level -> DropdownMenuItem({ AIText(level) }, { onEffortChange(level); effortOpen = false }) } }
        }
    }
}
