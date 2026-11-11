package dev.aielements.protocol

import kotlinx.serialization.json.*
import java.io.ByteArrayOutputStream

/** Buffers UTF-8 bytes, never assuming a transport chunk is a complete JSON object. */
class AIUIStreamDecoder(val maximumLineBytes: Int = 1_048_576) {
    private val buffer = ByteArrayOutputStream()
    init { require(maximumLineBytes > 0) }
    fun append(bytes: ByteArray, onEvent: (AIUIStreamEvent) -> Unit) {
        for (byte in bytes) {
            if (byte == 10.toByte()) {
                val line = buffer.toByteArray(); buffer.reset()
                if (line.any { it != 9.toByte() && it != 13.toByte() && it != 32.toByte() }) {
                    onEvent(AIUIJson.decodeFromString<AIUIStreamEvent>(line.decodeToString(throwOnInvalidSequence = true)))
                }
            } else {
                require(buffer.size() < maximumLineBytes) { "UI stream line exceeds size limit." }
                buffer.write(byte.toInt())
            }
        }
    }
    fun append(bytes: ByteArray): List<AIUIStreamEvent> = buildList { append(bytes) { add(it) } }
    fun finish(onEvent: (AIUIStreamEvent) -> Unit) { if (buffer.size() > 0) append(byteArrayOf(10), onEvent) }
    fun finish(): List<AIUIStreamEvent> = buildList { finish { add(it) } }
    fun reset() { buffer.reset() }
}
/** Single-surface transactional reducer. Call from one owner thread; networking belongs to the host. */
class AIUISession(initialDocument: AIUIDocument? = null) {
    enum class Phase { Idle, Streaming, Complete, Failed, Removed }
    var document: AIUIDocument? = initialDocument?.also { it.validate() }; private set
    var phase = if (initialDocument == null) Phase.Idle else Phase.Complete; private set
    var errorMessage: String? = null; private set
    private var surfaceID = initialDocument?.id
    private var lastRevision = initialDocument?.revision ?: -1
    fun apply(event: AIUIStreamEvent) {
        require(event.version == "1.0" && event.surfaceID.isNotEmpty() && event.surfaceID.length <= 128 && event.revision in 0..9_007_199_254_740_991L && (event.message?.toByteArray()?.size ?: 0) <= 32768) { "Invalid event identity/version." }
        require(event.kind in listOf("surface.begin", "surface.update", "surface.complete", "surface.error", "surface.remove")) { "Unknown event kind." }
        if (event.kind == "surface.begin") {
            require(phase == Phase.Idle || phase == Phase.Removed) { "Surface already exists." }
            val next = AIUIDocument(event.surfaceID, event.revision, requireNotNull(event.root), event.nodes ?: emptyMap(), event.state ?: emptyMap())
            next.validate(allowIncomplete = true)
            document = next; phase = Phase.Streaming; surfaceID = event.surfaceID; lastRevision = event.revision; errorMessage = null
            return
        }
        val current = requireNotNull(document) { "No surface." }
        require(event.surfaceID == surfaceID && event.baseRevision == lastRevision && event.revision == lastRevision + 1) { "Out-of-order UI event. Request a fresh snapshot." }
        require(phase != Phase.Failed || event.kind == "surface.remove") { "Failed surface is frozen." }
        when (event.kind) {
            "surface.remove" -> { document = null; phase = Phase.Removed; lastRevision = event.revision; errorMessage = null }
            "surface.error" -> { document = current.copy(revision = event.revision); lastRevision = event.revision; phase = Phase.Failed; errorMessage = event.message ?: "Generation interrupted." }
            else -> {
                val next = current.copy(root = event.root ?: current.root, revision = event.revision,
                    nodes = current.nodes - (event.removeNodes ?: emptyList()).toSet() + (event.nodes ?: emptyMap()),
                    state = current.state + (event.state ?: emptyMap()))
                next.validate(allowIncomplete = event.kind != "surface.complete")
                document = next; lastRevision = event.revision; errorMessage = null
                phase = if (event.kind == "surface.complete") Phase.Complete else Phase.Streaming
            }
        }
    }
    fun interrupt(message: String = "Generation interrupted. Replay to start again.") {
        if (phase == Phase.Streaming) { phase = Phase.Failed; errorMessage = message }
    }
    fun setValue(value: JsonElement, nodeID: String, property: String = "value") {
        val current = requireNotNull(document)
        val key = requireNotNull(current.nodes[nodeID]?.bindings?.get(property)) { "Control has no state binding." }
        val next = current.copy(state = current.state + (key to value))
        next.validate(allowIncomplete = phase == Phase.Streaming || phase == Phase.Failed)
        document = next
    }
    fun event(nodeID: String, event: String, value: JsonElement? = null): AIUIEvent? {
        val current = document ?: return null
        val action = current.nodes[nodeID]?.events?.get(event) ?: return null
        return AIUIEvent(current.id, current.revision, nodeID, action.name, event, value, action.payload,
            JsonObject(current.state.filterKeys { it in action.stateKeys }))
    }
}
