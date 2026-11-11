package dev.aielements.protocol

import kotlinx.serialization.json.*
import kotlin.math.abs

object AIUIComponentCatalog {
    val properties = mapOf(
        "Stack" to setOf("gap"), "Row" to setOf("gap"),
        "Card" to setOf("style", "title", "description", "footer", "footerIcon", "footnote"),
        "Text" to setOf("text", "variant"), "Button" to setOf("label", "variant", "disabled"),
        "Badge" to setOf("text", "variant"), "Input" to setOf("label", "placeholder", "value", "disabled"),
        "Select" to setOf("placeholder", "label", "value", "options", "disabled"),
        "Switch" to setOf("label", "value", "disabled"), "Progress" to setOf("label", "value", "max"),
        "Separator" to emptySet(), "Table" to setOf("columns", "rows", "caption", "footer"),
        "BarChart" to setOf("data", "series", "height", "label", "legend"),
        "LineChart" to setOf("data", "series", "height", "label", "legend"),
        "AreaChart" to setOf("data", "series", "height", "label", "legend"),
    )
    val types: List<String> get() = properties.keys.toList()
}
fun AIUIDocument.validate(allowIncomplete: Boolean = false) {
    require(version == "1.0") { "Unsupported UI version: $version" }
    require(id.isNotEmpty() && id.length <= 128 && root.isNotEmpty() && root.length <= 128 && revision in 0..9_007_199_254_740_991L) { "Invalid surface identity/revision." }
    require(nodes.size <= 256 && state.size <= 256) { "Surface exceeds 256 nodes/state keys." }
    require(allowIncomplete || root in nodes) { "Missing root: $root" }
    state.values.forEach { validateValue(it) }
    nodes.forEach { (id, node) ->
        require(id.isNotEmpty() && id.length <= 128) { "Invalid node ID." }
        val allowed = requireNotNull(AIUIComponentCatalog.properties[node.type]) { "Unsupported component: ${node.type}" }
        require(allowed.containsAll(node.props.keys + node.bindings.keys)) { "Unknown property on $id." }
        node.props.values.forEach { validateValue(it) }
        node.bindings.values.forEach {
            require(it.isNotEmpty() && it.length <= 128 && (allowIncomplete || it in state)) { "Invalid/missing binding: $it" }
        }
        require(node.children.size <= 256 && node.children.distinct().size == node.children.size) { "Duplicate/excessive children." }
        require(node.children.isEmpty() || node.type in listOf("Stack", "Row", "Card")) { "${node.type} cannot contain children." }
        node.events.forEach { (event, action) ->
            val supported = when {
                node.type == "Button" -> listOf("press")
                node.type in listOf("Input", "Select", "Switch") -> listOf("change")
                node.type.endsWith("Chart") -> listOf("select")
                else -> emptyList()
            }
            require(event in supported && action.name.isNotEmpty() && action.name.length <= 128 && action.stateKeys.size <= 256) { "Invalid action on $id." }
            action.payload.values.forEach { validateValue(it) }
        }
        validateProps(node.resolved(state), node.type, allowIncomplete)
    }
    val visiting = mutableSetOf<String>()
    val visited = mutableSetOf<String>()
    val parents = mutableMapOf<String, String>()
    // Walk every path: caching only by node would allow a staged deep subtree to bypass the depth limit.
    fun walk(id: String, depth: Int) {
        require(depth <= 32 && id !in visiting) { "UI exceeds depth limit or contains a cycle at $id." }
        val node = nodes[id]
        if (node == null) { require(allowIncomplete) { "Missing node: $id" }; return }
        visiting.add(id)
        node.children.forEach { child ->
            require(parents[child] == null || parents[child] == id) { "Node has multiple parents: $child" }
            parents[child] = id
            walk(child, depth + 1)
        }
        visiting.remove(id); visited.add(id)
    }
    walk(root, 0)
    nodes.keys.filter { it !in visited }.forEach { walk(it, 0) }
}
private fun validateValue(value: JsonElement, depth: Int = 0) {
    require(depth <= 16) { "Value nesting exceeds 16 levels." }
    when (value) {
        is JsonObject -> {
            require(value.size <= 256 && value.keys.all { it.length <= 128 }) { "Object exceeds limits." }
            value.values.forEach { validateValue(it, depth + 1) }
        }
        is JsonArray -> { require(value.size <= 1000); value.forEach { validateValue(it, depth + 1) } }
        is JsonPrimitive -> when {
            value.isString -> require(value.content.toByteArray().size <= 32768) { "Text exceeds 32 KiB." }
            value != JsonNull && value.booleanOrNull == null -> require(value.doubleOrNull?.let { it.isFinite() && abs(it) <= 1e15 } == true) { "Invalid number." }
        }
    }
}
private fun validateProps(p: JsonObject, type: String, incomplete: Boolean) {
    p.forEach { (key, value) ->
        if (key in listOf("title", "description", "footer", "footerIcon", "footnote", "text", "variant", "label", "placeholder", "caption") && !(type == "Table" && key == "footer")) require(value.textOrNull() != null) { "$key must be text." }
        if (key in listOf("disabled", "legend")) require(value.boolOrNull() != null) { "$key must be boolean." }
        if (key in listOf("height", "gap", "max")) require(value.numberOrNull() != null) { "$key must be numeric." }
    }
    p["footerIcon"]?.let { require(it.textOrNull() == "trending-up") }
    p["style"]?.let { require(it.textOrNull() in listOf("standard", "chart")) }
    p["height"]?.let { require(it.numberOrNull()!! in 120.0..600.0) }
    p["gap"]?.let { require(it.numberOrNull()!! in 0.0..48.0) }
    p["variant"]?.let { require(it.textOrNull() in if (type == "Text") listOf("body", "title", "caption", "muted", "label") else listOf("primary", "secondary", "outline", "ghost", "destructive")) }
    p["value"]?.let { require(when (type) { "Switch" -> it.boolOrNull() != null; "Progress" -> it.numberOrNull() != null; else -> it.textOrNull() != null }) { "Invalid value type." } }
    if (type == "Progress") {
        val max = p["max"].numberOrNull() ?: 100.0
        require(max > 0 && (p["value"].numberOrNull() ?: 0.0) in 0.0..max)
    }
    if (type == "Select") p["options"]?.let { options ->
        require(options is JsonArray && options.size <= 100)
        val ids = mutableSetOf<String>()
        options.forEach { require(it is JsonObject && it["label"].textOrNull() != null && it["value"].textOrNull()?.let(ids::add) == true) }
        p["value"].textOrNull()?.let { require(it.isEmpty() || it in ids) { "Selected value is absent from options." } }
    }
    if (type.endsWith("Chart")) {
        p["series"]?.let { series ->
            require(series is JsonArray && series.size in 1..5)
            val ids = mutableSetOf<String>()
            series.forEach { require(it is JsonObject && it["label"].textOrNull() != null && it["key"].textOrNull()?.let { key -> key != "label" && ids.add(key) } == true) }
        }
        p["data"]?.let { data ->
            require(data is JsonArray && data.size <= 200)
            val labels = mutableSetOf<String>()
            data.forEach { row ->
                require(row is JsonObject && row["label"].textOrNull()?.let(labels::add) == true)
                (p["series"] as? JsonArray)?.forEach { require(row[it.jsonObject["key"]!!.jsonPrimitive.content].numberOrNull() != null) }
            }
        }
        require(incomplete || (p["series"] != null && p["data"] != null)) { "Chart requires series and data." }
    }
    if (type == "Table") {
        p["footer"]?.let { require(it is JsonObject) }
        p["columns"]?.let { columns ->
            require(columns is JsonArray && columns.size in 1..12)
            val keys = mutableSetOf<String>()
            columns.forEach { col ->
                require(col is JsonObject && col["label"].textOrNull() != null && col["key"].textOrNull()?.let(keys::add) == true)
                col["width"]?.let { require(it.numberOrNull()?.let { n -> n in 24.0..600.0 } == true) }
                col["alignment"]?.let { require(it.textOrNull() in listOf("leading", "trailing")) }
                col["emphasized"]?.let { require(it.boolOrNull() != null) }
            }
        }
        p["rows"]?.let { require(it is JsonArray && it.all { row -> row is JsonObject }) }
    }
}
