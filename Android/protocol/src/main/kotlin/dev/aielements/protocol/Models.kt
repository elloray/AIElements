package dev.aielements.protocol

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.util.UUID

val AIUIJson = Json { ignoreUnknownKeys = true; encodeDefaults = true }

@Serializable
data class AIUIAction(val name: String, val payload: JsonObject = JsonObject(emptyMap()), val stateKeys: List<String> = emptyList())
@Serializable
data class AIUIEvent(
    val surfaceID: String, val revision: Long, val nodeID: String, val name: String,
    val event: String, val value: JsonElement? = null,
    val payload: JsonObject = JsonObject(emptyMap()), val state: JsonObject = JsonObject(emptyMap()),
    val id: String = UUID.randomUUID().toString(), val version: String = "1.0",
)
@Serializable
data class AIUINode(
    val type: String, val props: JsonObject = JsonObject(emptyMap()), val children: List<String> = emptyList(),
    val bindings: Map<String, String> = emptyMap(), val events: Map<String, AIUIAction> = emptyMap(),
) {
    fun resolved(state: Map<String, JsonElement>): JsonObject = JsonObject(props.toMutableMap().apply {
        bindings.forEach { (property, key) -> if (key in state) put(property, state.getValue(key)) else remove(property) }
    })
}
@Serializable
data class AIUIDocument(
    val id: String, val revision: Long = 0, val root: String, val nodes: Map<String, AIUINode>,
    val state: Map<String, JsonElement> = emptyMap(), val version: String = "1.0",
) {
    companion object {
        fun decode(bytes: ByteArray): AIUIDocument {
            require(bytes.size <= 1_048_576) { "UI document exceeds 1 MiB." }
            return AIUIJson.decodeFromString<AIUIDocument>(bytes.decodeToString(throwOnInvalidSequence = true)).also { it.validate() }
        }
    }
}
@Serializable
data class AIUIStreamEvent(
    val kind: String, val surfaceID: String, val revision: Long, val baseRevision: Long? = null,
    val root: String? = null, val nodes: Map<String, AIUINode>? = null, val removeNodes: List<String>? = null,
    val state: Map<String, JsonElement>? = null, val message: String? = null, val version: String = "1.0",
)
fun JsonElement?.textOrNull(): String? = (this as? JsonPrimitive)?.takeIf { it.isString }?.content
fun JsonElement?.numberOrNull(): Double? = (this as? JsonPrimitive)?.takeUnless { it.isString }?.doubleOrNull
fun JsonElement?.boolOrNull(): Boolean? = (this as? JsonPrimitive)?.takeUnless { it.isString }?.booleanOrNull
fun JsonElement?.displayText(): String = when (this) {
    null, JsonNull -> "—"
    is JsonPrimitive -> if (booleanOrNull != null && !isString) if (boolean) "Yes" else "No" else content
    else -> ""
}
object AIUIResources {
    val exampleNames = listOf("dashboard", "stack", "row", "card", "text", "button", "badge", "input", "select", "switch", "progress", "separator", "table", "bar-chart", "line-chart", "area-chart")
    fun bytes(name: String): ByteArray {
        require(name in exampleNames + listOf("schema", "dashboard-stream")) { "Unknown resource: $name" }
        val file = if (name == "dashboard-stream") "dashboard.jsonl" else "$name.json"
        return requireNotNull(javaClass.getResourceAsStream("/$file")) { "Missing resource: $file" }.use { it.readBytes() }
    }
}
