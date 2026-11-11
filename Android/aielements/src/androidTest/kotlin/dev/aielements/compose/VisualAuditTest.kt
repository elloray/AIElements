package dev.aielements.compose

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import java.io.File

/** Explicitly enabled visual evidence capture; does not change production component defaults. */
class VisualAuditTest {
    @get:Rule val compose = createComposeRule()

    private fun activate(text: String) {
        compose.onNode(hasClickAction() and (hasText(text) or hasAnyDescendant(hasText(text))))
            .performSemanticsAction(SemanticsActions.OnClick) { it() }
    }

    @Test fun captureMatchedExamples() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("visualAudit") == "true")
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val output = File(context.getExternalFilesDir(null), "visual-audit").apply { mkdirs() }
        var fixture by mutableStateOf("button")
        var dark by mutableStateOf(false)
        var generation by mutableIntStateOf(0)
        compose.setContent {
            AIElementsTheme(darkTheme = dark) {
                key(generation) {
                    Box(Modifier.width(360.dp).background(AITheme.colors.background).testTag("audit")) {
                        VisualAuditFixture(fixture)
                    }
                }
            }
        }
        val records = mutableListOf<String>()
        for (theme in listOf(false, true)) for (name in auditPatterns + auditFoundations) {
            compose.runOnIdle { fixture = name; dark = theme; generation++ }
            compose.waitForIdle()
            // Align states only where the Android component exposes an equivalent state.
            when (name) {
                "reasoning" -> activate("Thought for 5s")
                "terminal" -> { activate("Ran pnpm lint"); activate("Ran pnpm test") }
            }
            // Invoke semantic actions above to align state without a transient touch ripple.
            compose.mainClock.advanceTimeBy(1_000)
            compose.waitForIdle()
            val node = compose.onNodeWithTag("audit").assertWidthIsEqualTo(360.dp)
            val bounds = node.fetchSemanticsNode().boundsInRoot
            val bitmap = node.captureToImage().asAndroidBitmap()
            val key = "$name-${if (theme) "dark" else "light"}"
            File(output, "$key.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            File(output, "$key-semantics.txt").writeText(compose.onRoot().printToString())
            val density = context.resources.displayMetrics.density
            records += "\"$key\":{\"widthPx\":${bitmap.width},\"heightPx\":${bitmap.height},\"density\":$density,\"widthDp\":${bounds.width / density},\"heightDp\":${bounds.height / density}}"
            File(output, "metadata.json").writeText("{${records.joinToString(",")}}")
        }
        // Gradle removes the test APK afterward, including its external files directory.
        // Copy evidence to the emulator's shared Downloads before that cleanup.
        instrumentation.uiAutomation.executeShellCommand("mkdir -p /sdcard/Download/AIElementsAudit").use {
            android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
        }
        instrumentation.uiAutomation.executeShellCommand("cp -R ${output.absolutePath}/. /sdcard/Download/AIElementsAudit/").use {
            android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
        }
    }
}
