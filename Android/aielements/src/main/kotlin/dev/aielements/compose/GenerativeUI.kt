@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package dev.aielements.compose

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import dev.aielements.protocol.*
import kotlinx.serialization.json.*

/** UI-thread owner for a single surface. Failure preserves the last valid document. */
@Stable
class AIUIStore(initialDocument: AIUIDocument? = null) {
    private val session = AIUISession(initialDocument)
    private val decoder = AIUIStreamDecoder()
    var document by mutableStateOf(session.document); private set
    var phase by mutableStateOf(session.phase); private set
    var errorMessage by mutableStateOf<String?>(null); private set
    private fun publish() { document = session.document; phase = session.phase; errorMessage = session.errorMessage }
    fun receive(bytes: ByteArray) {
        try { decoder.append(bytes) { session.apply(it); publish() } }
        catch (e: Exception) { session.interrupt(e.message ?: "Invalid stream."); publish(); errorMessage = e.message; throw e }
    }
    fun receive(text: String) = receive(text.toByteArray(Charsets.UTF_8))
    fun finish() {
        try { decoder.finish { session.apply(it); publish() }; session.interrupt(); publish() }
        catch (e: Exception) { session.interrupt(e.message ?: "Incomplete stream."); publish(); errorMessage = e.message; throw e }
    }
    fun interrupt(message: String = "Generation stopped. Replay to start again.") { session.interrupt(message); publish() }
    /** Rejected edits keep the last valid value and surface an error instead of escaping the UI callback. */
    fun setValue(nodeID: String, value: JsonElement): Boolean {
        return try {
            session.setValue(value, nodeID)
            publish()
            true
        } catch (e: IllegalArgumentException) {
            errorMessage = e.message ?: "This value is not supported. Try another value."
            false
        }
    }
    fun event(nodeID: String, event: String, value: JsonElement? = null): AIUIEvent? = session.event(nodeID, event, value)
}
@Composable fun AIUIRenderer(store: AIUIStore, modifier: Modifier = Modifier, onEvent: ((AIUIEvent) -> Unit)? = null) {
    val doc = store.document
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (doc != null) RenderNode(doc.root, doc, store, onEvent)
        if (store.phase == AIUISession.Phase.Streaming) AIText("Generating…", muted = true, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
        store.errorMessage?.let { Text(it, color = AITheme.colors.destructive, style = AITypography.body, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }) }
    }
}
@Composable private fun RenderNode(id: String, doc: AIUIDocument, store: AIUIStore, onEvent: ((AIUIEvent) -> Unit)?) {
    val node = doc.nodes[id]
    if (node == null) { AIText("Loading…", muted = true); return }
    key(id) {
        val p = node.resolved(doc.state)
        fun str(key: String, default: String = "") = p[key].textOrNull() ?: default
        fun num(key: String, default: Double) = p[key].numberOrNull() ?: default
        fun bool(key: String, default: Boolean = false) = p[key].boolOrNull() ?: default
        fun objects(key: String) = (p[key] as? JsonArray)?.mapNotNull { it as? JsonObject } ?: emptyList()
        fun emit(event: String, value: JsonElement? = null) { store.event(id, event, value)?.let { onEvent?.invoke(it) } }
        fun change(value: JsonElement) {
            if ("value" in node.bindings && store.setValue(id, value)) emit("change", value)
        }
        val interactive = "value" in node.bindings
        when (node.type) {
            "Stack" -> AIStack(gap = num("gap", 12.0).dp) { node.children.forEach { RenderNode(it, doc, store, onEvent) } }
            "Row" -> AIRow(gap = num("gap", 8.0).dp) { node.children.forEach { RenderNode(it, doc, store, onEvent) } }
            "Card" -> AICard(title = str("title"), description = str("description"), footer = str("footer"), footnote = str("footnote"), chartStyle = str("style") == "chart", footerIcon = if (str("footerIcon") == "trending-up") AIIconName.trendingUp else null) {
                AIStack(gap = if (str("style") == "chart") 24.dp else 16.dp) { node.children.forEach { RenderNode(it, doc, store, onEvent) } }
            }
            "Text" -> AIText(str("text"), variant = str("variant", "body"))
            "Button" -> AIButton(str("label", "Continue"), variant = str("variant", "primary"), capsule = false, enabled = !bool("disabled") && "press" in node.events && store.phase != AIUISession.Phase.Failed && onEvent != null) { emit("press") }
            "Badge" -> AIBadge(str("text"), str("variant", "secondary"))
            "Input" -> AIInput(str("value"), { change(JsonPrimitive(it)) }, label = str("label"), placeholder = str("placeholder"), enabled = !bool("disabled") && interactive)
            "Select" -> AISelect(str("value"), objects("options").map { AIOption(it["value"].textOrNull().orEmpty(), it["label"].textOrNull().orEmpty()) }, { change(JsonPrimitive(it)) }, label = str("label"), placeholder = str("placeholder", "Select an option"), enabled = !bool("disabled") && interactive)
            "Switch" -> AISwitch(bool("value"), { change(JsonPrimitive(it)) }, str("label", "Switch"), enabled = !bool("disabled") && interactive)
            "Progress" -> AIProgress(num("value", 0.0).toFloat(), num("max", 100.0).toFloat(), str("label"))
            "Separator" -> AISeparator()
            "Table" -> AITable(objects("columns").map { AITableColumn(it["key"].textOrNull().orEmpty(), it["label"].textOrNull().orEmpty(), it["width"].numberOrNull()?.dp ?: androidx.compose.ui.unit.Dp.Unspecified, it["alignment"].textOrNull() == "trailing", it["emphasized"].boolOrNull() == true) },
                objects("rows").map { row -> row.mapValues { it.value.displayText() } }, caption = str("caption"), footer = (p["footer"] as? JsonObject)?.mapValues { it.value.displayText() })
            "BarChart", "LineChart", "AreaChart" -> {
                val series = objects("series").map { AIChartSeries(it["key"].textOrNull().orEmpty(), it["label"].textOrNull().orEmpty()) }
                val rows = objects("data").map { row -> AIChartRow(row["label"].textOrNull().orEmpty(), series.associate { it.key to (row[it.key].numberOrNull() ?: 0.0) }) }
                AIChart(rows, series, kind = when (node.type) { "LineChart" -> AIChartKind.Line; "AreaChart" -> AIChartKind.Area; else -> AIChartKind.Bar }, label = str("label", "Chart"), height = p["height"].numberOrNull()?.dp ?: androidx.compose.ui.unit.Dp.Unspecified, legend = bool("legend", false)) { row ->
                    emit("select", buildJsonObject { put("label", row.label); row.values.forEach { (k, v) -> put(k, v) } })
                }
            }
        }
    }
}
