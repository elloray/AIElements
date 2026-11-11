@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package dev.aielements.compose

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

enum class AIStatus { Pending, Running, Completed, Failed, Skipped }
internal val LocalAITraceContent = staticCompositionLocalOf { false }
private fun AIStatus.icon() = when (this) { AIStatus.Completed -> AIIconName.circleCheck; AIStatus.Failed -> AIIconName.circleX; AIStatus.Running -> AIIconName.circleDot; else -> AIIconName.circle }
@Composable fun AITrace(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) { Column(modifier, content = content) }
@Composable fun AITraceLine(title: String, status: AIStatus = AIStatus.Completed, detail: String? = null, modifier: Modifier = Modifier, icon: AIIconName? = status.icon()) {
    val ink = if (status == AIStatus.Failed) AITheme.colors.destructive else AITheme.colors.mutedForeground
    Row(modifier.heightIn(min = 20.dp).semantics(mergeDescendants = true) { stateDescription = status.name }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        icon?.let { AIIcon(it, color = ink) }
        Text(title, Modifier.weight(1f, fill = false), style = AITypography.body, color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        detail?.let { Text(it, style = AITypography.body, color = ink.copy(alpha = .7f)) }
    }
}
@Composable fun AITraceDisclosure(title: String, modifier: Modifier = Modifier, status: AIStatus = AIStatus.Completed, initiallyExpanded: Boolean = false,
    icon: AIIconName? = status.icon(), detail: String? = null, contentSpacing: Dp = 8.dp, content: @Composable ColumnScope.() -> Unit) {
    var expanded by rememberSaveable { mutableStateOf(initiallyExpanded) }
    val c = AITheme.colors; val ink = if (status == AIStatus.Failed) c.destructive else c.mutedForeground
    val holder = rememberSaveableStateHolder()
    Column(modifier) {
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button) { expanded = !expanded }
            .semantics { stateDescription = if (expanded) "Expanded, ${status.name}" else "Collapsed, ${status.name}" }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            AITraceLine(title, status, detail, Modifier.weight(1f, fill = false), icon)
            AIIcon(if (expanded) AIIconName.chevronDown else AIIconName.chevronRight, color = ink)
        }
        if (expanded) holder.SaveableStateProvider("content") {
            Column(Modifier.padding(start = 7.dp).drawBehind { drawLine(c.border, Offset.Zero, Offset(0f, size.height), 1.dp.toPx()) }
                .padding(start = 17.dp, end = 4.dp, bottom = 4.dp), verticalArrangement = Arrangement.spacedBy(contentSpacing)) {
                CompositionLocalProvider(LocalAITraceContent provides true) { content() }
            }
        }
    }
}
@Composable fun AICodeBlock(code: String, language: String = "", modifier: Modifier = Modifier, showCopy: Boolean = language.isNotBlank(),
    showLineNumbers: Boolean = language.isNotBlank(), wrap: Boolean = true, maxHeight: Dp = 256.dp) {
    val clipboard = LocalClipboardManager.current; val c = AITheme.colors
    val scroll = rememberScrollState()
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) { if (copied) { kotlinx.coroutines.delay(2000); copied = false } }
    val syntax = language.lowercase() in listOf("bash", "sh", "shell", "zsh")
    val codeStyle = AITypography.code.copy(fontSize = if (language.isEmpty()) 12.sp else 14.sp, lineHeight = if (language.isEmpty()) 20.sp else 22.75.sp)
    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(c.muted)) {
        if (language.isNotEmpty() || showCopy) Row(Modifier.padding(start = 16.dp, end = 4.dp).heightIn(min = if (showCopy) 48.dp else 36.dp), verticalAlignment = Alignment.CenterVertically) {
            AIText(language, Modifier.weight(1f), variant = "label")
            if (showCopy) AIIconButton(if (copied) AIIconName.check else AIIconName.copy, if (copied) "Copied" else "Copy code") { clipboard.setText(AnnotatedString(code)); copied = true }
        }
        SelectionContainer {
            Column(Modifier.fillMaxWidth().heightIn(max = maxHeight).drawWithContent {
                drawContent()
                if (scroll.canScrollForward) drawRect(Brush.verticalGradient(listOf(Color.Transparent, c.muted), startY = (size.height - 24.dp.toPx()).coerceAtLeast(0f), endY = size.height))
            }.verticalScroll(scroll)
                .then(if (!wrap) Modifier.horizontalScroll(rememberScrollState()) else Modifier)
                .padding(horizontal = if (language.isEmpty()) 12.dp else 16.dp)
                .padding(top = if (language.isEmpty()) 12.dp else 0.dp, bottom = 12.dp)) {
                code.trimEnd('\n').lines().forEachIndexed { i, line ->
                    val annotated = buildAnnotatedString {
                        val base = if (!syntax) c.foreground else if (c.dark) androidx.compose.ui.graphics.Color(0xFF9ECBFF) else androidx.compose.ui.graphics.Color(0xFF193D61)
                        withStyle(SpanStyle(color = base)) { append(line.ifEmpty { " " }) }
                        if (syntax) Regex("^\\s*([\\w./-]+)").find(line)?.groups?.get(1)?.let { token ->
                            addStyle(SpanStyle(color = if (c.dark) androidx.compose.ui.graphics.Color(0xFFB392F0) else androidx.compose.ui.graphics.Color(0xFF7040A3)), token.range.first, token.range.last + 1)
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (showLineNumbers) Text("${i + 1}", Modifier.widthIn(min = 24.dp).clearAndSetSemantics {}, color = c.mutedForeground, style = codeStyle, textAlign = androidx.compose.ui.text.style.TextAlign.End)
                        Text(annotated, style = codeStyle, softWrap = wrap)
                    }
                }
            }
        }
    }
}
private fun toolTitle(name: String, status: AIStatus) = when (status) { AIStatus.Completed -> "Ran $name"; AIStatus.Failed -> "Failed to run $name"; AIStatus.Running -> "Running $name"; AIStatus.Skipped -> "Skipped $name"; else -> name }
@Composable fun AITool(name: String, status: AIStatus = AIStatus.Completed, output: String? = null, input: String? = null, modifier: Modifier = Modifier, initiallyExpanded: Boolean = status == AIStatus.Failed, icon: AIIconName = AIIconName.terminal) {
    AITraceDisclosure(toolTitle(name, status), modifier, status, initiallyExpanded, icon = icon) {
        input?.let { AICodeBlock(it, "Input", showLineNumbers = false) }
        output?.let { AICodeBlock(it) }
        if (output == null) AIText(if (status == AIStatus.Running) "Running…" else "No output", muted = true)
    }
}
@Composable fun AITerminal(command: String, output: String, status: AIStatus = AIStatus.Completed, modifier: Modifier = Modifier) {
    AITraceDisclosure(toolTitle(command, status), modifier, status, initiallyExpanded = true, icon = AIIconName.terminal) { AICodeBlock(output) }
}
@Composable fun AIReasoning(text: String, isStreaming: Boolean = false, durationSeconds: Int? = null, modifier: Modifier = Modifier) {
    AITraceDisclosure(if (isStreaming) "Thinking…" else durationSeconds?.let { "Thought for ${it}s" } ?: "Thought", modifier,
        if (isStreaming) AIStatus.Running else AIStatus.Completed, initiallyExpanded = isStreaming, icon = if (durationSeconds == null && !isStreaming) AIIconName.circleCheck else null) { AIMessageResponse(text, muted = true) }
}
data class AIStep(val id: String, val title: String, val status: AIStatus = AIStatus.Pending, val detail: String? = null)
@Composable fun AIPlan(title: String, steps: List<AIStep>, modifier: Modifier = Modifier) {
    AITraceDisclosure("Plan: $title", modifier, initiallyExpanded = true, icon = AIIconName.route, detail = "${steps.count { it.status == AIStatus.Completed }} of ${steps.size} done") {
        steps.forEach { step -> key(step.id) { AITraceLine(step.title, step.status); step.detail?.let { AIText(it, muted = true) } } }
    }
}
@Composable fun AITask(title: String, steps: List<AIStep>, modifier: Modifier = Modifier) {
    AITraceDisclosure(title, modifier) { steps.forEach { step -> key(step.id) { AITraceLine(step.title, step.status); step.detail?.let { AICodeBlock(it) } } } }
}
@Composable fun AIChainOfThought(steps: List<AIStep>, modifier: Modifier = Modifier) {
    val status = if (steps.any { it.status == AIStatus.Failed }) AIStatus.Failed else if (steps.any { it.status == AIStatus.Running }) AIStatus.Running else AIStatus.Completed
    AITraceDisclosure("${if (status == AIStatus.Running) "Researching" else "Researched"} in ${steps.size} steps", modifier, status) {
        steps.forEach { step -> key(step.id) { AITraceDisclosure(step.title, status = step.status) { AIMessageResponse(step.detail ?: "No additional details.", muted = true) } } }
    }
}
@Composable fun AISubagent(title: String, status: AIStatus = AIStatus.Running, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    AITraceDisclosure("${if (status == AIStatus.Running) "Running" else if (status == AIStatus.Failed) "Failed" else "Ran"} the $title subagent", modifier, status, initiallyExpanded = true, contentSpacing = 0.dp, content = content)
}
@Composable fun AIQueue(items: List<AIStep>, modifier: Modifier = Modifier, onSelect: (AIStep) -> Unit = {}) {
    val groups = items.groupBy { it.status == AIStatus.Completed }
    AITrace(modifier) { listOf(false, true).forEach { completed -> groups[completed]?.let { group ->
        AITraceDisclosure("${group.size} ${if (completed) "completed" else "upcoming"}", initiallyExpanded = true, icon = AIIconName.listChecks, contentSpacing = 0.dp) {
            group.forEach { item -> key(item.id) { AITraceLine(item.title, item.status, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button) { onSelect(item) }) } }
        }
    } } }
}
data class AITestResult(val id: String, val name: String, val status: AIStatus, val detail: String? = null, val suite: String = "")
@Composable fun AITestResults(suite: String, tests: List<AITestResult>, modifier: Modifier = Modifier) {
    val failed = tests.count { it.status == AIStatus.Failed }
    @Composable fun Results(group: List<AITestResult>) {
        group.forEach { test -> key(test.id) {
            if (test.detail == null) AITraceLine(test.name, test.status, icon = if (test.status == AIStatus.Completed) AIIconName.check else test.status.icon())
            else AITraceDisclosure(test.name, status = test.status, initiallyExpanded = test.status == AIStatus.Failed, icon = if (test.status == AIStatus.Failed) AIIconName.x else test.status.icon()) { AICodeBlock(test.detail) }
        } }
    }
    AITraceDisclosure("Ran ${tests.size} tests${if (failed > 0) ", $failed failed" else ""}", modifier.semantics { contentDescription = suite },
        if (failed > 0) AIStatus.Failed else AIStatus.Completed, initiallyExpanded = true, icon = AIIconName.flaskConical, contentSpacing = 0.dp) {
        tests.groupBy { it.suite }.forEach { (file, group) ->
            if (file.isEmpty()) Results(group) else key(file) {
                val errors = group.count { it.status == AIStatus.Failed }
                AITraceDisclosure("$file, ${group.size} tests${if (errors > 0) ", $errors failed" else ""}", status = if (errors > 0) AIStatus.Failed else AIStatus.Completed,
                    initiallyExpanded = errors > 0, icon = AIIconName.fileCode, contentSpacing = 0.dp) { Results(group) }
            }
        }
    }
}
data class AIStackFrame(val id: String, val function: String, val file: String, val line: Int, val isFramework: Boolean = file.startsWith("node:") || file.contains("node_modules/"), val column: Int? = null)
@Composable fun AIStackTrace(error: String, frames: List<AIStackFrame>, modifier: Modifier = Modifier, onOpenSource: (AIStackFrame) -> Unit = {}) {
    @Composable fun Frame(frame: AIStackFrame) {
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button) { onOpenSource(frame) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AIIcon(AIIconName.fileCode)
            AIText("${frame.function} in ${frame.file}:${frame.line}${frame.column?.let { ":$it" } ?: ""}", muted = true)
        }
    }
    AITraceDisclosure("Failed: $error", modifier, AIStatus.Failed, initiallyExpanded = true, icon = AIIconName.terminal, contentSpacing = 0.dp) {
        Text(error, color = AITheme.colors.destructive, style = AITypography.code)
        frames.filterNot { it.isFramework }.forEach { frame -> key(frame.id) { Frame(frame) } }
        val framework = frames.filter { it.isFramework }
        if (framework.isNotEmpty()) AITraceDisclosure("${framework.size} framework frames", icon = AIIconName.layers) { framework.forEach { frame -> key(frame.id) { Frame(frame) } } }
    }
}
@Composable fun AIContext(input: Int, output: Int, reasoning: Int, limit: Int, modifier: Modifier = Modifier) {
    val used = input.toLong().coerceAtLeast(0) + output.toLong().coerceAtLeast(0) + reasoning.toLong().coerceAtLeast(0)
    var open by rememberSaveable { mutableStateOf(false) }
    Box(modifier) {
        AIButton("${if (limit > 0) (used * 100 / limit).coerceAtMost(100) else 0}% context", variant = "outline") { open = true }
        DropdownMenu(open, { open = false }, Modifier.width(280.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                AIText("Context usage", variant = "label"); AIProgress(used.toFloat(), limit.coerceAtLeast(1).toFloat())
                AIText("Input $input\nOutput $output\nReasoning $reasoning\nLimit $limit", muted = true)
            }
        }
    }
}
@Composable fun AICheckpoint(title: String, enabled: Boolean = true, modifier: Modifier = Modifier, onRestore: () -> Unit) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AISeparator(Modifier.weight(1f)); AIText(title, muted = true)
        AIButton("Restore", variant = "outline", compact = true, enabled = enabled, onClick = onRestore); AISeparator(Modifier.weight(1f))
    }
}
enum class AIConfirmationDecision { Pending, Approved, Denied }
/** Host owns approval and tool execution; failed callbacks remain retryable. */
@Composable fun AIConfirmation(title: String, description: String, decision: AIConfirmationDecision, onDecision: suspend (AIConfirmationDecision) -> Unit,
    modifier: Modifier = Modifier, executionStatus: AIStatus = AIStatus.Pending, output: String? = null) {
    var busy by remember { mutableStateOf(false) }; var failure by remember { mutableStateOf<String?>(null) }; val scope = rememberCoroutineScope()
    fun decide(value: AIConfirmationDecision) {
        if (busy) return
        busy = true; failure = null
        scope.launch { try { onDecision(value) } catch (e: CancellationException) { throw e } catch (e: Exception) { failure = e.message ?: "Could not save the decision. Try again." } finally { busy = false } }
    }
    @Composable fun Actions() {
        when (decision) {
            AIConfirmationDecision.Pending -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AIButton("Deny", variant = "outline", enabled = !busy) { decide(AIConfirmationDecision.Denied) }
                AIButton(if (busy) "Saving…" else "Approve", enabled = !busy) { decide(AIConfirmationDecision.Approved) }
            }
            AIConfirmationDecision.Approved -> AIBadge("Approved")
            AIConfirmationDecision.Denied -> AIBadge("Denied")
        }
    }
    val fontScale = LocalDensity.current.fontScale
    BoxWithConstraints(modifier.fillMaxWidth().border(1.dp, AITheme.colors.border, RoundedCornerShape(18.dp)).padding(16.dp)) {
        val stacked = maxWidth < 320.dp || fontScale > 1.2f
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                AIIcon(AIIconName.terminal, Modifier.padding(top = 2.dp), color = AITheme.colors.foreground)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    AIText(title, variant = "label"); AIText(description, muted = true)
                    if (stacked) Actions()
                }
                if (!stacked) Box(Modifier.align(Alignment.CenterVertically)) { Actions() }
            }
            if (decision == AIConfirmationDecision.Approved) AITool(title, executionStatus, output)
            failure?.let { Text(it, color = AITheme.colors.destructive, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }) }
        }
    }
}
