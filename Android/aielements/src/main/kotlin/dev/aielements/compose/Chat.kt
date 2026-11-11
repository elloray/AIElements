@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package dev.aielements.compose

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

// URI access and uploading stay with the host. No bytes are uploaded by the component library.
data class AIAttachment(val uri: Uri, val name: String, val mimeType: String? = null)
data class AIPromptSubmission(val text: String, val attachments: List<AIAttachment>)
enum class AIMessageRole { User, Assistant, System }
internal val LocalAIMessageUser = staticCompositionLocalOf { false }
data class AIChatMessage(val id: String, val role: AIMessageRole, val text: String, val attachments: List<AIAttachment> = emptyList())
@Composable fun AIAttachmentView(attachment: AIAttachment, modifier: Modifier = Modifier, onRemove: (() -> Unit)? = null) {
    Row(modifier.background(AITheme.colors.muted, RoundedCornerShape(8.dp)).padding(start = 10.dp, end = if (onRemove == null) 10.dp else 0.dp).heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AIIcon(AIIconName.file); AIText(attachment.name, Modifier.weight(1f, fill = false), variant = "caption")
        onRemove?.let { AIIconButton(AIIconName.x, "Remove ${attachment.name}", onClick = it) }
    }
}
@Composable fun AIPromptInput(text: String, onTextChange: (String) -> Unit, modifier: Modifier = Modifier,
    attachments: List<AIAttachment> = emptyList(), onAttachmentsChange: ((List<AIAttachment>) -> Unit)? = null,
    isStreaming: Boolean = false, isSubmitting: Boolean = false, placeholder: String = "Ask anything…",
    onStop: () -> Unit = {}, toolbar: @Composable () -> Unit = {}, sendAccent: Boolean = false, onSubmit: (AIPromptSubmission) -> Unit) {
    val context = LocalContext.current
    val latestAttachments by rememberUpdatedState(attachments)
    val latestChange by rememberUpdatedState(onAttachmentsChange)
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        val selected = uris.map { uri ->
            val name = runCatching { context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null } }.getOrNull() ?: "Attachment"
            // Persist document grants when supported so rotation/process restoration can keep host URIs usable.
            runCatching { context.contentResolver.takePersistableUriPermission(uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            AIAttachment(uri, name, context.contentResolver.getType(uri))
        }
        latestChange?.invoke((latestAttachments + selected).distinctBy { it.uri })
    }
    Column(modifier.fillMaxWidth().background(AITheme.colors.prompt, RoundedCornerShape(18.dp))) {
        if (attachments.isNotEmpty()) FlowRow(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            attachments.forEach { item -> key(item.uri) { AIAttachmentView(item, onRemove = if (onAttachmentsChange != null) ({ onAttachmentsChange(attachments - item) }) else null) } }
        }
        BasicTextField(text, onTextChange, Modifier.fillMaxWidth().padding(start = 13.dp, end = 13.dp, top = 13.dp, bottom = if (sendAccent) 3.dp else 11.dp)
            .heightIn(min = if (sendAccent) 32.dp else 40.dp).semantics { contentDescription = "Prompt" },
            enabled = !isSubmitting, minLines = if (sendAccent) 1 else 2, maxLines = 8,
            textStyle = AITypography.body.copy(color = AITheme.colors.foreground), cursorBrush = androidx.compose.ui.graphics.SolidColor(AITheme.colors.foreground),
            decorationBox = { inner -> Box { if (text.isEmpty()) AIText(placeholder, muted = true); inner() } })
        Row(Modifier.padding(horizontal = 3.dp), verticalAlignment = Alignment.Bottom) {
            if (onAttachmentsChange != null) AIIconButton(AIIconName.plus, "Attach files", enabled = !isSubmitting, variant = "outline") { picker.launch(arrayOf("*/*")) }
            Box(Modifier.weight(1f), contentAlignment = Alignment.BottomEnd) { toolbar() }
            if (isStreaming) AIButton("Stop", variant = "secondary", onClick = onStop)
            else AIIconButton(AIIconName.arrowUp, if (isSubmitting) "Sending" else "Send message", enabled = !isSubmitting && (text.isNotBlank() || attachments.isNotEmpty()), variant = "primary", accent = sendAccent) { onSubmit(AIPromptSubmission(text, attachments)) }
        }
    }
}
@Composable fun AIMessage(role: AIMessageRole, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = if (role == AIMessageRole.User) Alignment.TopEnd else Alignment.TopStart) {
        Column(if (role == AIMessageRole.User) Modifier.widthIn(max = maxWidth * .8f).background(AITheme.colors.muted, RoundedCornerShape(22.dp)).padding(horizontal = 12.dp, vertical = 11.dp) else Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)) { CompositionLocalProvider(LocalAIMessageUser provides (role == AIMessageRole.User)) { content() } }
    }
}
@Composable fun AIMessageActions(text: String, modifier: Modifier = Modifier, onRetry: (() -> Unit)? = null, onEdit: (() -> Unit)? = null, onFeedback: ((Boolean?) -> Unit)? = null) {
    val clipboard = LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }
    var feedback by rememberSaveable { mutableStateOf<Boolean?>(null) }
    LaunchedEffect(copied) { if (copied) { kotlinx.coroutines.delay(2000); copied = false } }
    FlowRow(modifier.fillMaxWidth(), horizontalArrangement = if (onEdit != null) Arrangement.End else Arrangement.Start) {
        AIIconButton(if (copied) AIIconName.check else AIIconName.copy, if (copied) "Copied" else "Copy message") { clipboard.setText(AnnotatedString(text)); copied = true }
        onEdit?.let { AIIconButton(AIIconName.pencil, "Edit message", onClick = it) }
        onFeedback?.let { callback ->
            AIIconButton(AIIconName.thumbsUp, if (feedback == true) "Remove helpful feedback" else "Helpful") { feedback = if (feedback == true) null else true; callback(feedback) }
            AIIconButton(AIIconName.thumbsDown, if (feedback == false) "Remove unhelpful feedback" else "Unhelpful") { feedback = if (feedback == false) null else false; callback(feedback) }
        }
        onRetry?.let { AIIconButton(AIIconName.rotateCcw, "Retry response", onClick = it) }
    }
}
/** Thread heading and reset action, with breathing room before the scrollable conversation. */
@Composable fun AIChatHeader(title: String, description: String, modifier: Modifier = Modifier,
    resetEnabled: Boolean = true, onReset: () -> Unit) {
    Row(modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.Top) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = AITheme.colors.foreground, style = AITypography.title.copy(fontSize = 16.sp, lineHeight = 24.sp))
            AIText(description, muted = true)
        }
        AIIconButton(AIIconName.rotateCw, "Reset conversation", enabled = resetEnabled, variant = "outline", visualAlignment = Alignment.TopEnd, onClick = onReset)
    }
}
/** Give the conversation a bounded height (e.g. Modifier.weight(1f)); history remains scrollable. */
@Composable fun AIChat(messages: List<AIChatMessage>, modifier: Modifier = Modifier, isStreaming: Boolean = false,
    onRetry: ((AIChatMessage) -> Unit)? = null, onEdit: ((AIChatMessage) -> Unit)? = null,
    emptyTitle: String = "What should we build?",
    emptyDescription: String = "The agent can read your code, run commands and make changes. Press send to start.") {
    val state = rememberLazyListState()
    val scope = rememberCoroutineScope()
    var follow by remember { mutableStateOf(true) }
    LaunchedEffect(state) {
        snapshotFlow { state.isScrollInProgress to state.canScrollForward }.collect { (scrolling, canForward) -> if (scrolling) follow = !canForward }
    }
    LaunchedEffect(messages.size, messages.lastOrNull()?.text, isStreaming) {
        if (follow && messages.isNotEmpty()) state.scrollToItem(messages.lastIndex, Int.MAX_VALUE)
    }
    BoxWithConstraints(modifier) {
        val compactEmpty = maxHeight < 200.dp
        if (messages.isEmpty() && maxHeight >= 40.dp) Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(if (compactEmpty) 8.dp else 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            if (!compactEmpty) {
                Box(Modifier.size(40.dp).background(AITheme.colors.muted, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) { AIIcon(AIIconName.messageCircleDashed, Modifier.size(20.dp), color = AITheme.colors.foreground) }
                Spacer(Modifier.height(16.dp))
            }
            Text(emptyTitle, style = AITypography.title.copy(fontSize = 18.sp, lineHeight = 28.sp, letterSpacing = (-.45).sp), color = AITheme.colors.foreground)
            if (!compactEmpty) {
                Spacer(Modifier.height(8.dp))
                Text(emptyDescription, Modifier.widthIn(max = 200.dp), color = AITheme.colors.mutedForeground, style = AITypography.body.copy(lineHeight = 22.75.sp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
        else if (messages.isNotEmpty()) LazyColumn(Modifier.fillMaxSize(), state = state, contentPadding = PaddingValues(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            items(messages, key = { it.id }) { message ->
                Column {
                    AIMessage(message.role) {
                        AIMessageResponse(message.text)
                        message.attachments.forEach { AIAttachmentView(it) }
                    }
                    AIMessageActions(message.text, onRetry = if (message.role == AIMessageRole.Assistant && onRetry != null && !isStreaming) ({ onRetry(message) }) else null,
                        onEdit = if (message.role == AIMessageRole.User && onEdit != null) ({ onEdit(message) }) else null)
                }
            }
        }
        if (!follow && state.canScrollForward) AIButton("Jump to latest", Modifier.align(Alignment.BottomCenter), "secondary") { follow = true; scope.launch { if (messages.isNotEmpty()) state.animateScrollToItem(messages.lastIndex, Int.MAX_VALUE) } }
    }
}
@Composable fun AIConversation(messages: List<AIChatMessage>, modifier: Modifier = Modifier, isStreaming: Boolean = false) { AIChat(messages, modifier, isStreaming) }
