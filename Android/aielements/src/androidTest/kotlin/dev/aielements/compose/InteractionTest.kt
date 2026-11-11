package dev.aielements.compose

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import dev.aielements.protocol.*
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InteractionTest {
    @get:Rule val compose = createComposeRule()
    @Test fun promptDisablesEmptySendAndSwitchesToStop() {
        var submitted = ""; var stopped = false
        var streaming by mutableStateOf(false)
        compose.setContent { AIElementsTheme { var text by remember { mutableStateOf("") }; AIPromptInput(text, { text = it }, isStreaming = streaming, onStop = { stopped = true }) { submitted = it.text } } }
        compose.onNodeWithContentDescription("Send message").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Prompt").performTextInput("Hello Android")
        compose.onNodeWithContentDescription("Send message").performClick()
        compose.runOnIdle { assertEquals("Hello Android", submitted); streaming = true }
        compose.onNodeWithText("Stop").performClick()
        compose.runOnIdle { assertTrue(stopped) }
    }
    @Test fun approvalFailureCanRetryWithoutDuplicateSubmission() {
        var attempts = 0
        compose.setContent { AIElementsTheme {
            var decision by remember { mutableStateOf(AIConfirmationDecision.Pending) }
            AIConfirmation("Approve demo", "Local action", decision, onDecision = {
                attempts++
                if (attempts == 1) error("Temporary failure")
                decision = it
            })
        } }
        compose.onNodeWithText("Approve").performClick()
        compose.onNodeWithText("Temporary failure").assertIsDisplayed()
        compose.onNodeWithText("Approve").performClick()
        compose.onNodeWithText("Approved").assertIsDisplayed()
        compose.runOnIdle { assertEquals(2, attempts) }
    }
    @Test fun fileTreeRetainsNestedExpansionAndSelectsByFullPath() {
        var selected = ""
        compose.setContent { AIElementsTheme { AIFileTree(listOf(AIFileNode("src", listOf(AIFileNode("src/ui", listOf(AIFileNode("src/ui/Chat.kt"))))))) { selected = it.path } } }
        compose.onNodeWithText("src").performClick()
        compose.onNodeWithText("ui").performClick()
        compose.onNodeWithText("src").performClick()
        compose.onNodeWithText("Chat.kt").assertDoesNotExist()
        compose.onNodeWithText("src").performClick()
        compose.onNodeWithText("Chat.kt").performClick()
        compose.runOnIdle { assertEquals("src/ui/Chat.kt", selected) }
    }
    @Test fun selectUpdatesBindingBeforeEmittingHostAction() {
        val store = AIUIStore(AIUIDocument.decode(AIUIResources.bytes("select")))
        var emitted: AIUIEvent? = null
        compose.setContent { AIElementsTheme { AIUIRenderer(store) { emitted = it } } }
        compose.onNodeWithContentDescription("Fruit").performClick()
        compose.onNodeWithText("Banana").performClick()
        compose.runOnIdle {
            assertEquals(JsonPrimitive("banana"), store.document!!.state["fruit"])
            assertEquals(JsonPrimitive("banana"), emitted!!.state["fruit"])
            assertEquals("change_fruit", emitted!!.name)
        }
    }
    @Test fun interruptedStoreKeepsRenderedContentAndFreezesRevision() {
        val store = AIUIStore()
        compose.setContent { AIElementsTheme { AIUIRenderer(store) } }
        compose.runOnIdle { store.receive("{\"version\":\"1.0\",\"kind\":\"surface.begin\",\"surfaceID\":\"s\",\"revision\":0,\"root\":\"r\",\"nodes\":{\"r\":{\"type\":\"Text\",\"props\":{\"text\":\"Last valid content\"}}}}\n"); store.interrupt("Offline") }
        compose.onNodeWithText("Last valid content").assertIsDisplayed()
        compose.onNodeWithText("Offline").assertIsDisplayed()
        compose.runOnIdle { assertEquals(AIUISession.Phase.Failed, store.phase); assertEquals(0L, store.document!!.revision) }
    }
    @Test fun controlsKeepIndependentAndroidTouchTargets() {
        compose.setContent { AIElementsTheme { Column {
            AIButton("Continue") {}
            AIButton("X") {}
            AIInput("", {}, label = "Name")
            AISelect("", listOf(AIOption("a", "Apple")), {}, label = "Fruit")
        } } }
        compose.onNodeWithText("Continue").assertHeightIsAtLeast(48.dp)
        compose.onNodeWithText("X").assertHeightIsAtLeast(48.dp).assertWidthIsAtLeast(48.dp)
        compose.onNodeWithContentDescription("Name").assertHeightIsAtLeast(48.dp)
        compose.onNodeWithContentDescription("Fruit").assertHeightIsAtLeast(48.dp)
    }
    @Test fun rejectedInputPreservesValueAndSuppressesCallbackThenRecovers() {
        val store = AIUIStore(AIUIDocument("form", root = "name", nodes = mapOf(
            "name" to AIUINode("Input", JsonObject(mapOf("label" to JsonPrimitive("Name"))),
                bindings = mapOf("value" to "name"), events = mapOf("change" to AIUIAction("edit", stateKeys = listOf("name"))))
        ), state = mapOf("name" to JsonPrimitive("Valid"))))
        var callbacks = 0
        compose.setContent { AIElementsTheme { AIUIRenderer(store) { callbacks++ } } }
        compose.onNodeWithContentDescription("Name").performTextReplacement("x".repeat(32769))
        compose.onNodeWithText("Text exceeds 32 KiB.").assertIsDisplayed()
        compose.onNodeWithContentDescription("Name").assertTextEquals("Valid")
        compose.runOnIdle {
            assertEquals(JsonPrimitive("Valid"), store.document!!.state["name"])
            assertEquals(0, callbacks)
        }
        compose.onNodeWithContentDescription("Name").performTextReplacement("Recovered")
        compose.onNodeWithText("Text exceeds 32 KiB.").assertDoesNotExist()
        compose.runOnIdle {
            assertEquals(JsonPrimitive("Recovered"), store.document!!.state["name"])
            assertEquals(1, callbacks)
        }
    }
    @Test fun allSharedFoundationDocumentsComposeInBothThemes() {
        var resource by mutableStateOf("stack")
        var dark by mutableStateOf(false)
        compose.setContent { AIElementsTheme(dark) { val store = remember(resource) { AIUIStore(AIUIDocument.decode(AIUIResources.bytes(resource))) }; AIUIRenderer(store) } }
        for (theme in listOf(false, true)) for (name in AIUIResources.exampleNames) {
            compose.runOnIdle { dark = theme; resource = name }
            compose.waitForIdle()
            compose.onRoot().assertExists()
        }
    }
}
