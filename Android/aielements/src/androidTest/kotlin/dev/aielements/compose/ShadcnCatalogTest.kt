package dev.aielements.compose

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class ShadcnCatalogTest {
    @get:Rule val compose = createComposeRule()
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val samples
        get() = AIShadcnCatalog.examples(instrumentation.targetContext)

    @Test
    fun checkboxAndAccordionReportChanges() {
        val events = mutableListOf<Pair<String, String>>()
        var kind by mutableStateOf("checkbox")
        val examples = samples.associateBy { it.id }
        compose.setContent {
            AIElementsTheme {
                key(kind) {
                    AIShadcnView(examples.getValue(kind).root) { id, v -> events += id to v }
                }
            }
        }
        compose.onNodeWithText("Accept terms and conditions").performClick()
        compose.runOnIdle {
            assertEquals("true", events.last().second)
            kind = "accordion"
        }
        compose.onNodeWithText("What is your return policy?").performClick()
        compose.runOnIdle { assertEquals("returns", events.last().second) }
    }

    @Test
    fun questionnaireValidatesRequiredAnswersAndRetainsThemWhenNavigatingBack() {
        val entry = samples.single { it.id == "questionnaire" }
        val state = AIShadcnState()
        compose.setContent { AIElementsTheme { AIShadcnView(entry.root, state = state) } }
        compose.onNodeWithText("Next").performClick()
        compose.onNodeWithText("Select an answer to continue.").assertExists()
        compose.onNodeWithText("Only the target component").performClick()
        compose.onNodeWithText("Next").performClick()
        compose.onNodeWithText("Question 2 of 3").assertExists()
        compose.onNodeWithText("Back").performClick()
        compose.onNodeWithText("Only the target component").assertIsSelected()
        compose.runOnIdle {
            assertEquals("Only the target component", state.values["questionnaire/0"])
        }
    }

    @Test
    fun selectingADataTableRowSurvivesFilteringAndSorting() {
        val entry = samples.single { it.id == "data-table" }
        val state = AIShadcnState()
        compose.setContent { AIElementsTheme { AIShadcnView(entry.root, state = state) } }
        compose.onNodeWithContentDescription("Select row 1").performClick()
        compose.onNodeWithText("1 of 5 row(s) selected.").assertExists()
        compose
            .onNodeWithContentDescription("Select all rows on this page")
            .assert(
                SemanticsMatcher.expectValue(
                    androidx.compose.ui.semantics.SemanticsProperties.ToggleableState,
                    androidx.compose.ui.state.ToggleableState.Indeterminate,
                )
            )
        compose.onNodeWithText("Email").performClick()
        compose.onNode(hasSetTextAction()).performTextInput("ken99")
        compose.onNodeWithText("1 of 1 row(s) selected.").assertExists()
        compose.runOnIdle { assertEquals("true", state.values["data-table/row/0"]) }
        compose.onNode(hasSetTextAction()).performTextReplacement("Success")
        compose.onNodeWithText("No results.").assertExists()
    }

    @Test
    fun tableSelectionStaysWithItsHostIdAfterRefresh() {
        val state = AIShadcnState()
        var table by
            mutableStateOf(
                AIShadcnNode(
                    AIShadcnKind.DataTable,
                    columns = listOf("Name"),
                    rows = listOf(listOf("A"), listOf("B")),
                    rowIDs = listOf("alpha", "bravo"),
                )
            )
        compose.setContent { AIElementsTheme { AIShadcnView(table, state = state) } }
        compose.onNodeWithContentDescription("Select row 1").performClick()
        compose.runOnIdle {
            table =
                table.copy(
                    rows = listOf(listOf("B"), listOf("Renamed")),
                    rowIDs = listOf("bravo", "alpha"),
                )
        }
        compose.onNodeWithContentDescription("Select row 2").assertIsOn()
        compose.onNodeWithContentDescription("Select row 1").assertIsOff()
        compose.runOnIdle { assertEquals("true", state.values["data-table/row/alpha"]) }
    }

    @Test
    fun questionnaireRejectsUnavailableAnswersAndRestartsOnlyItsOwnQuestions() {
        val state = AIShadcnState(mapOf("scope" to "Retired", "unrelated" to "keep"))
        val node =
            AIShadcnNode(
                AIShadcnKind.Questionnaire,
                children =
                    listOf(
                        AIShadcnNode(
                            AIShadcnKind.RadioGroup,
                            id = "scope",
                            items =
                                listOf(
                                    AIShadcnItem("Retired", disabled = true),
                                    AIShadcnItem("Active"),
                                ),
                        )
                    ),
            )
        compose.setContent { AIElementsTheme { AIShadcnView(node, state = state) } }
        compose.onNodeWithText("Submit").performClick()
        compose.onNodeWithText("Select an answer to continue.").assertExists()
        compose.onNodeWithText("Active").performClick()
        compose.onNodeWithText("Submit").performClick()
        compose.onNodeWithText("Start again").performClick()
        compose.onNodeWithText("Active").assertIsNotSelected()
        compose.runOnIdle { assertEquals(mapOf("unrelated" to "keep"), state.values.toMap()) }
    }

    @Test
    fun sonnerQueuesNotificationsAndUndoDismissesOne() {
        val events = mutableListOf<Pair<String, String>>()
        val sample = samples.single { it.id == "sonner" }
        compose.setContent {
            AIElementsTheme { AIShadcnView(sample.root) { id, value -> events += id to value } }
        }
        compose.mainClock.autoAdvance = false
        compose.onNodeWithText("Show Toast").performClick()
        compose.mainClock.advanceTimeByFrame()
        compose.onNodeWithText("Show Toast").performClick()
        compose.mainClock.advanceTimeByFrame()
        compose.onAllNodesWithText("Event has been created").assertCountEquals(2)
        compose.onAllNodesWithText("Undo")[0].performClick()
        compose.mainClock.advanceTimeByFrame()
        compose.onAllNodesWithText("Event has been created").assertCountEquals(1)
        compose.runOnIdle { assertEquals("sonner" to "Undo", events.single()) }
        compose.mainClock.advanceTimeBy(4100)
        compose.onAllNodesWithText("Event has been created").assertCountEquals(0)
    }

    @Test
    fun renderEveryOfficialComponent() {
        val entries = samples
        assertEquals(AIShadcnKind.entries.size - 4, entries.map { it.id }.toSet().size)
        var index by mutableIntStateOf(0)
        var dark by mutableStateOf(false)
        val save = InstrumentationRegistry.getArguments().getString("shadcnSnapshots") == "true"
        val context = instrumentation.targetContext
        val output =
            File(context.getExternalFilesDir(null), "shadcn-audit").apply { if (save) mkdirs() }
        compose.setContent {
            AIElementsTheme(dark) {
                key(index, dark) {
                    Box(
                        Modifier.width(360.dp)
                            .heightIn(min = 64.dp)
                            .background(AITheme.colors.background)
                            .testTag("fixture"),
                        contentAlignment = Alignment.Center,
                    ) {
                        AIShadcnView(entries[index].root)
                    }
                }
            }
        }
        for ((i, entry) in entries.withIndex()) for (night in listOf(false, true)) {
            compose.runOnIdle {
                index = i
                dark = night
            }
            val fixture = compose.onNodeWithTag("fixture")
            fixture.assertIsDisplayed()
            if (save)
                File(output, entry.id + "-" + (if (night) "dark" else "light") + ".png")
                    .outputStream()
                    .use {
                        fixture
                            .captureToImage()
                            .asAndroidBitmap()
                            .compress(Bitmap.CompressFormat.PNG, 100, it)
                    }
        }
        if (save) {
            val destination = "/sdcard/Download/AIElementsShadcn"
            for (command in
                listOf("mkdir -p $destination", "cp -R ${output.absolutePath}/. $destination/")) {
                instrumentation.uiAutomation.executeShellCommand(command).use {
                    android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
                }
            }
        }
    }
}
