package dev.aielements.protocol

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.Test
import kotlin.test.*

class ProtocolTest {
    private fun stream() = AIUIStreamDecoder().append(AIUIResources.bytes("dashboard-stream"))
    private fun completeSession() = AIUISession().also { s -> stream().forEach(s::apply) }
    private fun node(type: String, props: String = "{}", children: List<String> = emptyList()) = AIUINode(type, AIUIJson.parseToJsonElement(props).jsonObject, children)
    @Test fun allSharedFixturesValidate() {
        AIUIResources.exampleNames.forEach { name -> assertNotNull(AIUIDocument.decode(AIUIResources.bytes(name)), name) }
        assertEquals(15, AIUIComponentCatalog.types.size)
    }
    @Test fun sharedStreamProducesSameDashboard() {
        val session = completeSession()
        assertEquals(AIUISession.Phase.Complete, session.phase)
        assertEquals(15, session.document!!.revision)
        assertEquals(6, session.document!!.nodes.getValue("chart").props.getValue("data").jsonArray.size)
    }
    @Test fun decoderAcceptsEveryByteBoundaryIncludingUnicode() {
        val json = AIUIJson.encodeToString(AIUIStreamEvent("surface.begin", "测试🧪", 0, root = "r"))
        val bytes = (json + "\r\n").toByteArray()
        for (split in 0..bytes.size) {
            val d = AIUIStreamDecoder()
            val events = d.append(bytes.copyOfRange(0, split)) + d.append(bytes.copyOfRange(split, bytes.size)) + d.finish()
            assertEquals("测试🧪", events.single().surfaceID)
        }
    }
    @Test fun decoderAcceptsFinalLineWithoutNewline() { val d = AIUIStreamDecoder(); d.append(AIUIJson.encodeToString(stream().first()).toByteArray()); assertEquals(1, d.finish().size) }
    @Test fun decoderRejectsTruncationOversizeAndInvalidUtf8() {
        val d = AIUIStreamDecoder(); d.append("{\"version\":".toByteArray()); assertFails { d.finish() }
        assertFails { AIUIStreamDecoder(4).append("12345".toByteArray()) }
        assertFails { AIUIStreamDecoder().append(byteArrayOf(0xff.toByte(), 10)) }
    }
    @Test fun validFramesAreDeliveredBeforeMalformedFrame() {
        var count = 0
        val data = (AIUIJson.encodeToString(stream().first()) + "\ninvalid\n").toByteArray()
        assertFails { AIUIStreamDecoder().append(data) { count++ } }
        assertEquals(1, count)
    }
    @Test fun revisionsAreTransactional() {
        val s = completeSession(); val before = s.document
        assertFails { s.apply(AIUIStreamEvent("surface.update", "report", 18, 15)) }
        assertEquals(before, s.document)
        assertFails { s.apply(AIUIStreamEvent("surface.update", "report", 16, 15, nodes = mapOf("bad" to node("WebView")))) }
        assertEquals(before, s.document)
        s.apply(AIUIStreamEvent("surface.update", "report", 16, 15)); assertEquals(16, s.document!!.revision)
    }
    @Test fun failedSurfaceIsFrozenUntilRemoved() {
        val s = AIUISession(); s.apply(stream().first()); s.interrupt("Lost connection")
        assertEquals(AIUISession.Phase.Failed, s.phase)
        assertFails { s.apply(stream()[1]) }
        s.apply(AIUIStreamEvent("surface.remove", "report", 1, 0)); assertNull(s.document)
        s.apply(stream().first()); assertEquals(AIUISession.Phase.Streaming, s.phase)
    }
    @Test fun explicitErrorRetainsLastValidSurface() {
        val s = completeSession(); val nodes = s.document!!.nodes
        s.apply(AIUIStreamEvent("surface.error", "report", 16, 15, message = "Connection closed"))
        assertEquals(nodes, s.document!!.nodes); assertEquals("Connection closed", s.errorMessage)
    }
    @Test fun localEditsSurviveUnrelatedUpdatesAndActionsExportOnlyOptedInState() {
        val s = completeSession()
        s.setValue(JsonPrimitive("My report"), "name")
        s.apply(AIUIStreamEvent("surface.update", "report", 16, 15, state = mapOf("secret" to JsonPrimitive("local-only"))))
        assertEquals(JsonPrimitive("My report"), s.document!!.state["reportName"])
        val event = s.event("submit", "press")!!
        assertEquals(setOf("reportName", "period", "compare"), event.state.keys)
        assertFalse("secret" in event.state)
    }
    @Test fun invalidLocalEditsAreAtomic() {
        val s = completeSession(); val before = s.document
        assertFails { s.setValue(JsonPrimitive("not-a-boolean"), "compare") }
        assertEquals(before, s.document)
    }
    @Test fun cyclesSharedChildrenAndDepthAreRejectedEvenWhenStaged() {
        assertFails { AIUIDocument("s", root = "a", nodes = mapOf("a" to node("Stack", children = listOf("b")), "b" to node("Stack", children = listOf("a")))).validate(true) }
        assertFails { AIUIDocument("s", root = "r", nodes = mapOf("r" to node("Stack", children = listOf("a", "b")), "a" to node("Stack", children = listOf("c")), "b" to node("Stack", children = listOf("c")), "c" to node("Text"))).validate() }
        val deep = (0..34).associate { "$it" to node("Stack", children = if (it < 34) listOf("${it + 1}") else emptyList()) }
        assertFails { AIUIDocument("s", root = "0", nodes = deep).validate() }
    }
    @Test fun incompleteNodesAreAllowedOnlyDuringStreaming() {
        val d = AIUIDocument("s", root = "r", nodes = mapOf("r" to node("Stack", children = listOf("later"))))
        d.validate(true); assertFails { d.validate() }
    }
    @Test fun invalidControlsAndChartDataAreRejected() {
        listOf(node("Progress", "{\"value\":101}"), node("Switch", "{\"value\":\"true\"}"), node("Text", "{\"html\":\"<b>x</b>\"}"),
            node("Select", "{\"value\":\"x\",\"options\":[{\"value\":\"a\",\"label\":\"A\"}]}"),
            node("BarChart", "{\"series\":[{\"key\":\"v\",\"label\":\"Value\"}],\"data\":[{\"label\":\"Jan\"}]}"))
            .forEach { n -> assertFails { AIUIDocument("s", root = "r", nodes = mapOf("r" to n)).validate() } }
    }
    @Test fun documentAndActionRoundTrip() {
        val s = completeSession(); val doc = s.document!!
        assertEquals(doc, AIUIDocument.decode(AIUIJson.encodeToString(doc).toByteArray()))
        val event = s.event("submit", "press")!!
        assertEquals(event, AIUIJson.decodeFromString<AIUIEvent>(AIUIJson.encodeToString(event)))
    }
}
