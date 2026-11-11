package dev.aielements.compose

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class VisualParityInteractionTest {
    @get:Rule val compose = createComposeRule()

    @Test fun cardFormKeepsSeparateEditingAndButtonTargetsAtLargeFont() {
        var fontScale by mutableStateOf(1f)
        compose.setContent {
            val current = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(current.density, fontScale)) {
                AIElementsTheme { Box(Modifier.width(360.dp)) { VisualAuditFixture("card") } }
            }
        }
        for (scale in listOf(1f, 1.3f)) {
            compose.runOnIdle { fontScale = scale }
            val email = compose.onNodeWithContentDescription("Email")
            val forgot = compose.onNode(hasClickAction() and hasText("Forgot your password?"))
            val password = compose.onNodeWithContentDescription("Input")
            val login = compose.onNode(hasClickAction() and hasText("Login", substring = false))
            val google = compose.onNode(hasClickAction() and hasText("Login with Google"))
            listOf(email, forgot, password, login, google).forEach { it.assertIsDisplayed().assertHeightIsAtLeast(48.dp) }
            val rows = listOf(email, forgot, password, login, google).map { it.getUnclippedBoundsInRoot() }
            rows.zipWithNext().forEach { (above, below) -> assertTrue(above.bottom <= below.top) }
            rows.forEach { assertTrue(it.left >= 0.dp && it.right <= 360.dp) }
        }
    }

    @Test fun chatHeaderResetRemainsReachableWhenItsDescriptionWraps() {
        var resets = 0
        compose.setContent {
            val current = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(current.density, 1.3f)) {
                AIElementsTheme { AIChatHeader("New Thread", "Ask the agent to change your code.", Modifier.width(280.dp)) { resets++ } }
            }
        }
        val reset = compose.onNodeWithContentDescription("Reset conversation")
        reset.assertIsDisplayed().assertHeightIsAtLeast(48.dp).performClick()
        val description = compose.onNodeWithText("Ask the agent to change your code.").getUnclippedBoundsInRoot()
        assertTrue(description.right <= reset.getUnclippedBoundsInRoot().left)
        compose.runOnIdle { assertEquals(1, resets) }
    }

    @Test fun narrowApprovalKeepsReadableDescriptionAboveSeparateActions() {
        var decision by mutableStateOf(AIConfirmationDecision.Pending)
        val description = "This is a local approval demonstration. No command is executed."
        compose.setContent { AIElementsTheme {
            AIConfirmation("Clean up the build folder?", description, decision, { decision = it }, Modifier.width(320.dp))
        } }
        val copy = compose.onNodeWithText(description).getUnclippedBoundsInRoot()
        val deny = compose.onNode(hasClickAction() and hasText("Deny"))
        val approve = compose.onNode(hasClickAction() and hasText("Approve"))
        deny.assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        approve.assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        assertTrue(copy.right - copy.left >= 200.dp)
        assertTrue(copy.bottom <= approve.getUnclippedBoundsInRoot().top)
        assertTrue(deny.getUnclippedBoundsInRoot().right <= approve.getUnclippedBoundsInRoot().left)
        approve.performClick()
        compose.onNodeWithText("Approved").assertIsDisplayed()
    }

    @Test fun chatEmptyTitleRemainsVisibleInAShortLandscapePane() {
        var paneHeight by mutableStateOf(80.dp)
        compose.setContent { AIElementsTheme { AIChat(emptyList(), Modifier.width(360.dp).height(paneHeight)) } }
        compose.onNodeWithText("What should we build?").assertIsDisplayed()
        val bounds = compose.onNodeWithText("What should we build?").getUnclippedBoundsInRoot()
        assertTrue(bounds.top >= 0.dp && bounds.bottom <= 80.dp)
        compose.runOnIdle { paneHeight = 20.dp }
        compose.onNodeWithText("What should we build?").assertDoesNotExist()
    }
    @Test fun invoiceAmountsFitThePhoneWithoutHorizontalScrolling() {
        compose.setContent { AIElementsTheme { Box(Modifier.width(360.dp)) { VisualAuditFixture("table") } } }
        compose.onNodeWithText("Amount").assertIsDisplayed()
        compose.onNodeWithText("$2,500.00").assertIsDisplayed()
        compose.onNodeWithText("$250.00").assertIsDisplayed()
        val bounds = compose.onNodeWithText("$2,500.00").getUnclippedBoundsInRoot()
        assertTrue(bounds.right <= 360.dp)
    }
    @Test fun invoiceRowsRemainSeparateAtLargeFontAndAmountsCanBeReached() {
        compose.setContent {
            val current = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(current.density, 1.5f)) {
                AIElementsTheme { Box(Modifier.width(320.dp)) { VisualAuditFixture("table") } }
            }
        }
        val first = compose.onNodeWithText("INV001").getUnclippedBoundsInRoot()
        val second = compose.onNodeWithText("INV002").getUnclippedBoundsInRoot()
        assertTrue(first.bottom < second.top)
        compose.onNodeWithText("$2,500.00").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Amount").assertIsDisplayed()
    }
    @Test fun inlineSourceKeepsExpandedTouchAreaAndOpensItsDetails() {
        compose.setContent { AIElementsTheme { Box(Modifier.width(360.dp)) { AICitedText(listOf(AICitedPart.Text("Read the documentation "),
            AICitedPart.Citation(listOf(AISource("Streaming", "https://nextjs.org/docs"))), AICitedPart.Text(" before starting."))) } } }
        compose.onNodeWithContentDescription("Sources: nextjs.org").assertTouchHeightIsEqualTo(48.dp).performClick()
        compose.onNodeWithText("Streaming").assertIsDisplayed()
        compose.onNodeWithText("Close").performClick()
        compose.onNodeWithText("Streaming").assertDoesNotExist()
    }
    @Test fun frameworkFramesExpandAndRetainSourceCallbacks() {
        var opened = ""
        compose.setContent { AIElementsTheme { Box(Modifier.width(360.dp)) { AIStackTrace("Example failure", listOf(
            AIStackFrame("app", "seed", "seed.ts", 10), AIStackFrame("lib", "run", "node_modules/lib.js", 12)
        )) { opened = it.id } } } }
        compose.onNodeWithText("run in node_modules/lib.js:12").assertDoesNotExist()
        compose.onNodeWithText("1 framework frames").performClick()
        compose.onNodeWithText("run in node_modules/lib.js:12").performClick()
        compose.runOnIdle { assertEquals("lib", opened) }
    }
    @Test fun groupedTestsExposeCollapsedPassingSuite() {
        compose.setContent { AIElementsTheme { Box(Modifier.width(360.dp)) { VisualAuditFixture("test-results") } } }
        compose.onNodeWithText("adds an item").assertDoesNotExist()
        compose.onNodeWithText("cart.test.ts, 3 tests").performClick()
        compose.onNodeWithText("adds an item").assertIsDisplayed()
        compose.onNodeWithText("retries a declined card").assertIsDisplayed()
    }
    @Test fun contextMenuAndSwitchStillRespondToTouch() {
        var checked by mutableStateOf(false)
        compose.setContent { AIElementsTheme { Column { AIContext(8420, 1260, 980, 128000); AISwitch(checked, { checked = it }, "Airplane Mode") } } }
        compose.onNodeWithContentDescription("Airplane Mode").performClick().assertIsOn()
        compose.onNodeWithText("8% context").performClick()
        compose.onNodeWithText("Context usage").assertIsDisplayed()
        compose.onNodeWithText("Input 8420", substring = true).assertIsDisplayed()
    }
    @Test fun chartDataRemainsAvailableThroughLongPress() {
        compose.setContent { AIElementsTheme { AIChart(listOf(AIChartRow("January", mapOf("value" to 10.0))), listOf(AIChartSeries("value", "Visits")), Modifier.width(360.dp), label = "Visitors") } }
        compose.onNodeWithContentDescription("Visitors.", substring = true).performTouchInput { longClick() }
        compose.onNodeWithText("Visitors", substring = false).assertIsDisplayed()
        compose.onNodeWithText("January: Visits 10.0").assertIsDisplayed()
        compose.onNodeWithText("Close").performClick()
    }

    @Test fun denseQueueRowsHaveSeparateTouchTargetsAndCallbacks() {
        var selected = ""
        compose.setContent { AIElementsTheme { Box(Modifier.width(360.dp)) {
            AIQueue(listOf(AIStep("one", "First task", AIStatus.Completed), AIStep("two", "Second task", AIStatus.Completed))) { selected = it.id }
        } } }
        val first = compose.onNode(hasClickAction() and hasText("First task"))
        val second = compose.onNode(hasClickAction() and hasText("Second task"))
        first.assertHeightIsAtLeast(48.dp); second.assertHeightIsAtLeast(48.dp)
        assertTrue(first.getUnclippedBoundsInRoot().bottom <= second.getUnclippedBoundsInRoot().top)
        first.performTouchInput { click(Offset(center.x, height - 2f)) }
        compose.runOnIdle { assertEquals("one", selected) }
        second.performTouchInput { click(Offset(center.x, 2f)) }
        compose.runOnIdle { assertEquals("two", selected) }
    }

    @Test fun promptMenusReflowWithoutOverlappingAtLargeFontScale() {
        compose.setContent {
            val current = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(current.density, 1.3f)) {
                AIElementsTheme { Box(Modifier.width(360.dp)) { VisualAuditFixture("prompt-input") } }
            }
        }
        val model = compose.onNode(hasClickAction() and hasText("GPT-5"))
        val effort = compose.onNode(hasClickAction() and hasText("Effort  Medium"))
        model.assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        effort.assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        val a = model.getUnclippedBoundsInRoot(); val b = effort.getUnclippedBoundsInRoot()
        assertTrue(a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top)
        assertTrue(a.right <= 360.dp && b.right <= 360.dp)
        model.performClick(); compose.onNodeWithText("GPT-5 mini").assertIsDisplayed()
    }

    @Test fun inlineCodeRetainsReadableTextAndWrapsLongTokens() {
        val code = "very_long_identifier_".repeat(8)
        compose.setContent { AIElementsTheme { Box(Modifier.width(240.dp)) {
            AIMessageResponse("Edit `site-header.tsx`.\n\nThen inspect `$code`.")
        } } }
        compose.onNodeWithText("Edit site-header.tsx.").assertIsDisplayed()
        val longText = compose.onNodeWithText("Then inspect $code.")
        longText.assertIsDisplayed()
        assertTrue(longText.getUnclippedBoundsInRoot().right <= 240.dp)
    }
}
