package dev.aielements.gallery

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.aielements.compose.*
import dev.aielements.protocol.*
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import java.util.UUID

private val models = listOf(AIModel("gpt-5", "GPT-5", "OpenAI"), AIModel("gpt-5-mini", "GPT-5 mini", "OpenAI"), AIModel("claude-sonnet", "Claude Sonnet", "Anthropic"))
private val sources = listOf(AISource("Jetpack Compose", "https://developer.android.com/compose", "Android’s native UI toolkit."), AISource("Kotlin", "https://kotlinlang.org/docs/home.html", "Kotlin language documentation."))
private val steps = listOf(AIStep("inspect", "Inspect the existing components", AIStatus.Completed, "Found the theme, inputs and message components."), AIStep("port", "Port the components to Compose", AIStatus.Running, "Preserve the existing Geist typography and state callbacks."), AIStep("verify", "Build and verify the gallery", AIStatus.Pending))
@Composable private fun Composer(onResult: (String) -> Unit = {}) {
    var text by rememberSaveable { mutableStateOf("") }
    var attachments by remember { mutableStateOf(emptyList<AIAttachment>()) }
    var model by rememberSaveable { mutableStateOf("gpt-5") }
    var effort by rememberSaveable { mutableStateOf("Medium") }
    AIPromptInput(text, { text = it }, attachments = attachments, onAttachmentsChange = { attachments = it }, toolbar = { AIModelSelector(models, model, { model = it }, effort = effort, onEffortChange = { effort = it }) }) {
        onResult("Submitted locally: ${it.text.ifEmpty { "${it.attachments.size} attachment(s)" }}")
        text = ""; attachments = emptyList()
    }
}
@Composable fun ChatDemo(modifier: Modifier = Modifier) {
    var text by rememberSaveable { mutableStateOf("") }
    var messages by remember { mutableStateOf(emptyList<AIChatMessage>()) }
    var streaming by remember { mutableStateOf(false) }
    var attachments by remember { mutableStateOf(emptyList<AIAttachment>()) }
    var model by rememberSaveable { mutableStateOf("gpt-5") }
    var job by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()
    fun respond(prompt: String) {
        val id = UUID.randomUUID().toString()
        messages += AIChatMessage(id, AIMessageRole.Assistant, "")
        streaming = true
        job = scope.launch {
            try {
                val answer = "This is a **local streaming demo**.\n\nYour request: $prompt\n\nEmbed `AIChat` and `AIPromptInput` in your app, then connect your own model service. The host owns networking, storage, and tool execution."
                for (chunk in answer.chunked(4)) { delay(30); messages = messages.map { if (it.id == id) it.copy(text = it.text + chunk) else it } }
            } finally { streaming = false }
        }
    }
    BoxWithConstraints(modifier) {
    val showSuggestions = maxHeight >= 280.dp
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (showSuggestions) AIChatHeader("New Thread", "Ask the agent to change your code.") {
            job?.cancel(); messages = emptyList(); text = ""; attachments = emptyList()
        }
        AIChat(messages, Modifier.weight(1f), streaming, onRetry = { message ->
            val i = messages.indexOfFirst { it.id == message.id }
            val prompt = messages.take(i).lastOrNull { it.role == AIMessageRole.User }?.text ?: "Try again"
            messages = messages.take(i); respond(prompt)
        }, onEdit = { text = it.text })
        if (messages.isEmpty() && showSuggestions) AISuggestions(listOf("Add a dark mode toggle", "Explain streaming UI")) { text = it }
        AIPromptInput(text, { text = it }, attachments = attachments, onAttachmentsChange = { attachments = it }, isStreaming = streaming,
            onStop = { job?.cancel() }, sendAccent = true, toolbar = { AIModelSelector(models, model, { model = it }) }) { submission ->
            messages += AIChatMessage(UUID.randomUUID().toString(), AIMessageRole.User, submission.text, submission.attachments)
            text = ""; attachments = emptyList(); respond(submission.text.ifEmpty { "Inspect these attachments" })
        }
        Spacer(Modifier.height(8.dp))
    }
}
}

@Composable fun FoundationDemo(name: String) {
    val store = remember(name) { AIUIStore(AIUIDocument.decode(AIUIResources.bytes(name))) }
    var event by remember { mutableStateOf("") }
    AIUIRenderer(store) { event = AIUIJson.encodeToString(it) }
    if (event.isNotEmpty()) AICodeBlock(event, "Host callback")
}
@Composable fun GenerativeDemo() {
    var store by remember { mutableStateOf(AIUIStore()) }
    var running by remember { mutableStateOf(false) }
    var event by remember { mutableStateOf("") }
    var job by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()
    fun replay() {
        job?.cancel()
        val next = AIUIStore(); store = next; running = true; event = ""
        job = scope.launch {
            try {
                val lines = AIUIResources.bytes("dashboard-stream").decodeToString().lineSequence().filter { it.isNotBlank() }
                for (line in lines) { next.receive("$line\n"); delay(220) }
                next.finish()
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { next.interrupt(e.message ?: "Generation failed") }
            finally { if (store === next) running = false }
        }
    }
    LaunchedEffect(Unit) { replay() }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AIButton("Replay", enabled = !running, onClick = ::replay)
        AIButton("Stop", variant = "outline", enabled = running) { job?.cancel(); store.interrupt() }
    }
    AIUIRenderer(store) { event = AIUIJson.encodeToString(it) }
    if (event.isNotEmpty()) AICodeBlock(event, "Host callback")
}
@Composable fun PatternDemo(name: String) {
    var notice by remember { mutableStateOf("") }
    when (name) {
        "Generative UI" -> GenerativeDemo()
        "Chain of Thought" -> { AIMessage(AIMessageRole.User) { AIText("How should we build the Android version?") }; AIChainOfThought(steps) }
        "Checkpoint" -> {
            var restored by rememberSaveable { mutableStateOf(false) }
            AIMessage(AIMessageRole.Assistant) { AIText("Renamed Button to Action in the demo.") }
            AICheckpoint(if (restored) "Restored" else "Restore checkpoint", enabled = !restored) { restored = true; notice = "Local checkpoint restored." }
            if (!restored) AIText("Updated the documentation to match.")
        }
        "Confirmation" -> {
            var decision by rememberSaveable { mutableStateOf(AIConfirmationDecision.Pending) }
            var status by remember { mutableStateOf(AIStatus.Pending) }
            LaunchedEffect(decision) { if (decision == AIConfirmationDecision.Approved) { status = AIStatus.Running; delay(900); status = AIStatus.Completed } }
            AIConfirmation("Clean up the build folder?", "This is a local approval demonstration. No command is executed.", decision,
                onDecision = { delay(200); decision = it }, executionStatus = status, output = if (status == AIStatus.Completed) "Demo completed. No files were removed." else null)
            AIButton("Reset", variant = "outline") { decision = AIConfirmationDecision.Pending; status = AIStatus.Pending }
        }
        "Context" -> AIContext(8420, 1260, 980, 128000)
        "File Tree" -> {
            var selection by rememberSaveable { mutableStateOf<String?>(null) }
            AIFileTree(listOf(AIFileNode("app", listOf(AIFileNode("app/MainActivity.kt"), AIFileNode("app/Theme.kt"))), AIFileNode("components", listOf(AIFileNode("components/Chat.kt"), AIFileNode("components/PromptInput.kt")))), selection) { selection = it.path; notice = "Selected ${it.path}" }
        }
        "Inline Citation" -> AICitedText(listOf(AICitedPart.Text("Build native Android interfaces with Jetpack Compose."), AICitedPart.Citation(sources), AICitedPart.Text("The library uses Kotlin and follows system accessibility settings.")))
        "Message" -> {
            AIMessage(AIMessageRole.User) { AIText("How do I add a settings dialog?") }
            AIMessage(AIMessageRole.Assistant) { AIMessageResponse("Use an **AlertDialog** with a host-owned state.\n\n```kotlin\nvar open by remember { mutableStateOf(false) }\n```\n\nDismiss it using Android’s Back gesture or its close action.") }
            AIMessageActions("Use an AlertDialog.", onRetry = { notice = "Retry requested locally." }, onFeedback = { notice = "Feedback: ${it ?: "cleared"}" })
        }
        "Model Selector", "Prompt Input" -> Composer { notice = it }
        "Plan" -> AIPlan("Android port", steps)
        "Queue" -> AIQueue(steps) { notice = "Selected ${it.title}" }
        "Reasoning" -> {
            var running by rememberSaveable { mutableStateOf(true) }
            AIReasoning("Inspecting the existing theme and component boundaries before adapting the controls for Android.", running, 4)
            AIButton(if (running) "Finish thinking" else "Replay", variant = "outline") { running = !running }
        }
        "Sources" -> AISources(sources)
        "Stack Trace" -> AIStackTrace("IllegalStateException: missing state binding", listOf(AIStackFrame("1", "renderInput", "GenerativeUI.kt", 42), AIStackFrame("2", "renderSurface", "MainActivity.kt", 81))) { notice = "Open ${it.file}:${it.line}" }
        "Subagent" -> AISubagent("Inspect components", AIStatus.Completed) { AIPlan("Review", steps.map { it.copy(status = AIStatus.Completed) }); AIText("The component interfaces are ready for the host.") }
        "Suggestion" -> { AISuggestions(listOf("Add dark mode", "Fix the failing build", "Write tests for the form")) { notice = "Selected: $it" }; Composer { notice = it } }
        "Task" -> AITask("Prepare the Android gallery", steps)
        "Terminal" -> AITerminal("./gradlew :gallery:assembleDebug", "Demo output\n> Task :gallery:assembleDebug\nBUILD SUCCESSFUL", AIStatus.Completed)
        "Test Results" -> AITestResults("Protocol tests", listOf(AITestResult("1", "Accept a split UTF-8 event", AIStatus.Completed), AITestResult("2", "Reject an out-of-order revision", AIStatus.Completed), AITestResult("3", "Example failing assertion", AIStatus.Failed, "Demo failure: expected 3, received 2."), AITestResult("4", "Network integration", AIStatus.Skipped, "Host networking is outside the component library.")))
        "Tool" -> { AITool("Read Theme.kt", AIStatus.Completed, "Found light and dark palettes.", "{\"path\":\"Theme.kt\"}"); AITool("Build the app", AIStatus.Running); AITool("Example failed command", AIStatus.Failed, "Demo error: missing input.") }
    }
    if (notice.isNotEmpty()) AIText(notice, muted = true)
}
