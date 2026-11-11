# AIElements for Android

Native **Kotlin + Jetpack Compose** counterpart to this repository’s SwiftUI library. Android 8.0 / API 26+, compile/target SDK 35, JDK 17. This is an unofficial independent port of shadcn/ui’s visual patterns; see the repository’s [third-party notices](../THIRD_PARTY_NOTICES.md).

- `aielements`: reusable composables, Geist / Geist Mono, Lucide vectors, light/dark themes and native 48 dp touch targets.
- `protocol`: platform-independent Kotlin JSONL decoder, validator and surface reducer. Uses the **same checked-in JSON fixtures and schema** as Swift.
- `gallery`: searchable 21-pattern catalog, 15 foundation examples and a progressive generative UI demo. Phone list/detail navigation, tablet split view, system/light/dark appearance.

The gallery is entirely local. It does not call a model, upload attachments, run commands or make real approval decisions.

## Build and run

Open this `Android` folder in Android Studio, with JDK 17 and Android SDK 35 installed. Android Studio can write `local.properties` for your SDK, or set `ANDROID_HOME`.

```sh
./gradlew :gallery:assembleDebug
./gradlew :gallery:installDebug
./gradlew :protocol:test :aielements:testDebugUnitTest
./gradlew :aielements:connectedDebugAndroidTest
./gradlew :aielements:lintDebug :gallery:lintDebug
```

The debug APK is `gallery/build/outputs/apk/debug/gallery-debug.apk`. The Gradle wrapper pins Gradle 8.11.1; the project pins AGP 8.9.1, Kotlin/Compose compiler 2.1.20 and Compose BOM 2025.04.01. It does not need an Apple signing identity. No release signing keys or store publication are configured.

## Add to an existing app

Keep this repository checkout available, then include its two library modules in your app’s `settings.gradle.kts`:

```kotlin
include(":aielements", ":protocol")
project(":aielements").projectDir = file("../AIElements/Android/aielements")
project(":protocol").projectDir = file("../AIElements/Android/protocol")
```

Declare compatible Android/Kotlin/Compose/serialization plugins in your root build, and Google / Maven Central repositories, as shown in this folder’s build files. In the app module:

```kotlin
dependencies { implementation(project(":aielements")) }
```

```kotlin
import dev.aielements.compose.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.util.UUID

@Composable
fun AssistantScreen() {
    var draft by rememberSaveable { mutableStateOf("") }
    var messages by remember { mutableStateOf(emptyList<AIChatMessage>()) }
    AIElementsTheme {
        Column(Modifier.fillMaxSize().safeDrawingPadding().imePadding().padding(16.dp)) {
            AIChat(messages, Modifier.weight(1f))
            AIPromptInput(draft, { draft = it }) { submission ->
                messages = messages + AIChatMessage(
                    UUID.randomUUID().toString(), AIMessageRole.User, submission.text
                )
                draft = ""
                // Call your service here and update messages using stable IDs.
            }
        }
    }
}
```

The host owns model requests, coroutine lifetime, persistence, retry decisions and attachment processing. Supply `attachments` and `onAttachmentsChange` to enable the Android document picker; the host clears accepted attachments. Attachments carry content URIs, not filesystem paths. Treat external URI grants as fallible when reading them.

`AIChatHeader` provides a title, description and host-owned reset callback. Omit it in very short panes, as the gallery does in landscape. `AICard` spaces its header, body and footer; use `AIStack(gap = …)` inside its body when separate children need spacing. JSON-rendered cards preserve their existing 16 dp body spacing (24 dp for charts). `AIButton(variant = "link")` aligns a text action with a field edge while keeping its independent 48 dp target.

`AIConfirmation` places actions below the description when its inner width is below 320 dp or the system font scale exceeds 1.2, preserving readable copy and separate touch targets.

## Pattern APIs

| Pattern | Public Compose API |
| --- | --- |
| Chain of Thought | `AIChainOfThought` |
| Chat | `AIChat`, `AIConversation`, `AIChatHeader` |
| Checkpoint | `AICheckpoint` |
| Confirmation | `AIConfirmation` |
| Context | `AIContext` |
| File Tree | `AIFileTree` |
| Inline Citation | `AICitedText`, `AIInlineCitation` |
| Message | `AIMessage`, `AIMessageResponse`, `AIMessageActions` |
| Model Selector | `AIModelSelector` |
| Plan | `AIPlan` |
| Prompt Input | `AIPromptInput` |
| Queue | `AIQueue` |
| Reasoning | `AIReasoning` |
| Sources | `AISources` |
| Stack Trace | `AIStackTrace` |
| Subagent | `AISubagent` |
| Suggestion | `AISuggestion`, `AISuggestions` |
| Task | `AITask` |
| Terminal | `AITerminal` |
| Test Results | `AITestResults` |
| Tool | `AITool` |

Foundation APIs: `AIStack`, `AIRow`, `AICard`, `AIText`, `AIButton`, `AIBadge`, `AIInput`, `AISelect`, `AISwitch`, `AIProgress`, `AISeparator`, `AITable`, `AIBarChart`, `AILineChart`, `AIAreaChart`. Helpers include `AITrace`, `AITraceLine`, `AITraceDisclosure`, `AICodeBlock`, `AIAttachmentView`, `AIIcon`.

Use `AIElementsTheme(darkTheme = true)` to override the system theme. Default text uses scalable `sp`; layouts grow with text. Menus and dialogs remain Android controls, and system Back works as expected. Compact buttons, switches and input surfaces retain Android touch semantics and 48 dp hit areas. Library composables do not impose navigation or window insets; apply those in the host.

`AIChat` requires a bounded height, such as `Modifier.weight(1f)` inside a full-height `Column`. It follows incoming content until the user scrolls away, then offers “Jump to latest”. Supply stable message and step IDs. Confirmation callbacks are suspending: failures show retryable errors, and execution starts only when the host changes the decision to approved. File-tree selection and expansion can be host-controlled. `AIChat` accepts custom empty-state text. `AICard` provides `headerAction` and `footerContent` slots; `AITestResult.suite` groups tests, and `AIStackFrame.isFramework` groups library frames. Traces preserve nested disclosure state when collapsed.

## Streaming UI

The wire format is the existing [AIElements UI 1.0 protocol](../Documentation/StreamingUI.md), not a proprietary OpenAI format. The renderer accepts all 15 node types. No generated HTML, JavaScript, expressions or executable commands are evaluated.

```kotlin
val store = remember { AIUIStore() }
AIUIRenderer(store) { event ->
    // Serialize AIUIEvent and forward it to your host/service.
}
// On the UI thread, as transport bytes arrive:
store.receive(bytes)
// When the transport closes:
store.finish()
```

`receive(ByteArray)` handles partial UTF-8 and JSON lines. Use bytes for arbitrary network chunks; `receive(String)` assumes the transport has already decoded Unicode correctly. Rejected local form edits retain their last valid value, show a recoverable error, and do not emit a change callback. Protocol transport errors throw after preserving the last valid frame and setting an error message. `finish()` marks an unterminated generation as interrupted. Create a new store to replay; a failed session cannot accept updates until removed. The reducer requires monotonically ordered revisions and validates updates before committing them. Local bound input survives updates that do not explicitly replace that state key. Events export only the action’s explicit `stateKeys`.

All store methods must run on the UI thread. The lower-level `AIUISession` and `AIUIStreamDecoder` have no UI dependency; confine each instance to one owner thread.

## Scope and differences

This implementation shares pattern coverage and protocol fixtures with the Swift library. The [latest 360 dp comparison report](../Documentation/Android-Visual-Fidelity-2026-11-11.md) records the corrected visuals and remaining platform differences, rather than claiming pixel equivalence or complete Swift API parity. Interactive rows retain 48 dp targets, so some lists and cards are taller than the website.

Citations participate in paragraph line breaking and open native source dialogs. Markdown supports paragraphs, headings, bold, inline code, web links and fenced code blocks; tables, images, nested rich lists, math and Mermaid require a host renderer. Code blocks support line numbers, basic Shell command highlighting, selection and scrolling; they are not a general syntax-highlighting engine. Charts use natural cubic splines and automatic axis bounds; tap to select a value, or long-press / use the “View data” accessibility action to open the data list. Tables measure content with its actual font weight and fit their columns where possible, retaining horizontal scrolling when the content cannot fit. Row borders are painted within each row to avoid cumulative height rounding; large text can still increase row height.

`AIIconButton.visualAlignment` positions the visible icon surface within its independent 48 dp target. The default is centered; `AIChatHeader` aligns its reset surface to the top/end without moving the touch target.

The existing root `aielements` CLI continues to generate Swift; use the Kotlin source and gallery demos for Android integration.

Validation evidence and the remaining device matrix are recorded in [Android validation](../Documentation/Android-Validation.md).
