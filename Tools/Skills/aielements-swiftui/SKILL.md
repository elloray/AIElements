---
name: aielements-swiftui
description: Build or modify native SwiftUI interfaces with elloray/AIElements on iOS, iPadOS, and macOS. Use for its AI chat patterns, foundation components, forms, tables, charts, and streamed JSONL interfaces with host action callbacks. Does not apply to React shadcn projects or model backend implementation alone.
---

# AIElements SwiftUI

Use this package's actual Swift API rather than translating React props. It is an
independent, unofficial port of shadcn/ui AI Elements, foundation designs and charts. Preserve upstream attribution
and applicable licenses when copying or redistributing reference material.

## Start from a checkout

This file can be read directly from the repository; installing a Skill or global CLI
is optional. Reuse a known AIElements checkout. If none exists, clone
`https://github.com/elloray/AIElements.git` into a new suitable directory, normally
beside the host project. Do not replace an existing directory or copy the library's
sources into the app. Read the checkout's README for integration instructions.

Use the checkout's `aielements` script. It builds the CLI on first use and reuses
SwiftPM's build cache afterward; no installation or PATH change is required.
It requires macOS and Swift 5.9+. Keep the host project as the working directory;
paths passed to the CLI are relative to that directory.

## Discover the API

Replace `/path/to/AIElements` below with the actual checkout path. Query only the
components needed for the task:

```sh
/path/to/AIElements/aielements list --search chat --json
/path/to/AIElements/aielements show chat --json
/path/to/AIElements/aielements example prompt-input
/path/to/AIElements/aielements show select --json
/path/to/AIElements/aielements show LineChart --json
```

`show` includes public symbol names, implementation paths, behavioral notes, the
original design URL, and a complete Swift source example. The catalog contains
21 AI patterns, 15 foundation nodes, and one `streaming-ui` integration example.
IDs such as `file-tree`, symbols such as `AIFileTree`, and protocol types such as
`LineChart` work. Shared `AIChart` symbols require choosing `bar-chart`, `line-chart`,
or `area-chart`. `protocolType` identifies a JSON node; an empty `symbols` array
means no standalone Swift constructor is exposed. JSON envelopes use `schemaVersion: 1`;
errors are on stderr with nonzero exit status. The checkout launcher may also emit
SwiftPM diagnostics on stderr. Examples and the catalog ship with the CLI; queries
do not call a model service or require network access after the checkout is available.

If the CLI is unavailable, read `Tools/Catalog/catalog.json` and the relevant
`Tools/Catalog/Examples/*.swift` in the library checkout. If neither is available,
obtain the repository within the user's task scope. Do not guess constructors.
Compare the installed library revision with the CLI checkout when APIs differ.

## Integrate with the host

- Inspect the existing Package.swift or Xcode project before editing dependencies.
  Add `https://github.com/elloray/AIElements.git`, product `AIElements`, and
  `import AIElements`. Minimum platforms: iOS/iPadOS 17, macOS 14; Swift tools 5.9.
  Do not silently raise an existing app's deployment target.
- The repository currently documents the `main` branch; preserve an existing
  pinned revision. Do not invent a version tag. Commit the host's resolved version
  or pin a commit when reproducibility is needed.
- For a requested new reusable UI package, preview with
  `/path/to/AIElements/aielements init --path NEW_DIR --name AssistantUI --dry-run --json`, then run
  without `--dry-run`. `--local-package PATH` uses a checkout;
  `--revision FULL_SHA` pins the remote package. The result exposes
  `AssistantChatView()` to an existing app. It is not an Xcode app project.
- Existing directories are refused. For an existing project, adapt the component
  example to its structure; do not regenerate or replace the project.

## Preserve these behaviors

- Keep IDs stable across streamed message/step updates. Update the existing reply,
  not a fresh UUID on each chunk. `AIChat(isStreaming:)` handles following output;
  custom `AIConversation` content needs an updated `revision`.
- The host owns the network/model task, cancellation, and data persistence.
  `AIPromptInput` does not clear itself. Clear its binding and increment
  `attachmentResetID` only after accepting a submission; preserve both on failure.
  Connect `onStop` to cancellation. File URL access and upload belong to the host.
- Use `AIMessageText` for user bubbles, `AIMessageResponse` for Markdown,
  and the `footer` slot for message actions. Use `AICitedText` for wrapping inline
  citations, not a separate HStack of text and badges.
- `AIConfirmation.submitDecision` is async/throwing; failure leaves the decision
  pending for retry. Approval is distinct from execution completion. In `AIChat`,
  handle `onToolApproval` and update the corresponding part with the real result.
- Terminal, tool, file-tree, and subagent views display host state. They do not
  execute shell commands, edit files, or spawn agents. Reasoning views should
  display summaries available from the provider, not hidden model reasoning.
- Use the default system theme. For explicit dark mode, pair `.aiTheme(.dark)`
  with `.preferredColorScheme(.dark)` so system sheets match.
- Preserve iOS `.comfortable` density and at least 44 pt touch targets. macOS
  defaults to `.reference`. Do not force reference density on touch devices just
  to match a browser screenshot. Fonts register automatically; no Info.plist
  font entries or global UIAppearance changes are needed.

## Verify the change

Build the affected host target, not just the CLI. For a UI package use `swift build`
on macOS; for iOS use the project's existing Xcode scheme and a simulator target.
Check affected screens in both appearances and at the same content width when
visual parity matters. Report any unavailable platform verification accurately.
Do not change signing identities or add model credentials to make a UI demo run.

For more state and attachment details, read `Documentation/Usage.md` in the library
checkout or [the published guide](https://github.com/elloray/AIElements/blob/main/Documentation/Usage.md).
Original patterns: [shadcn/ui AI Elements](https://ui.shadcn.com/docs/ai-elements).

## Stream native interfaces

For AI-generated interactive UI, read `Documentation/StreamingUI.md` in the checkout.
Use the same checkout script for all commands; a global CLI is not required:

```sh
/path/to/AIElements/aielements example streaming-ui
/path/to/AIElements/aielements ui schema
/path/to/AIElements/aielements ui example select > /tmp/select.json
/path/to/AIElements/aielements ui validate /tmp/select.json
/path/to/AIElements/aielements ui stream > /tmp/report.jsonl
/path/to/AIElements/aielements ui validate /tmp/report.jsonl
```

`example COMPONENT` emits Swift; `ui example NAME` emits a complete JSON document.
NAME accepts `dashboard` or any of the 15 foundation slugs below. `ui stream` emits
incremental dashboard events as JSONL. `ui schema/example/stream` emit raw artifacts
even with `--json`, not CLI result envelopes. Fallback files are in
`Sources/AIElementsUIProtocol/Resources/`; Swift examples are in `Tools/Catalog/Examples/`.

| Protocol types | CLI slugs |
| --- | --- |
| Stack, Row, Card, Text, Separator | stack, row, card, text, separator |
| Button, Badge, Progress | button, badge, progress |
| Input, Select, Switch | input, select, switch |
| Table | table |
| BarChart, LineChart, AreaChart | bar-chart, line-chart, area-chart |

For native composition, query `show` for exact constructors. Stack/Row/Text/Badge/
Separator examples use the renderer; do not invent AIStack/AIRow/AIText/AISeparator.
The existing `AIBadge` helper is not the protocol Badge's five-variant API.
Card defaults to `standard`; use `chart` for the roomier chart example. Native
Card header/footer view slots and AIInput secure/accessory options are not JSON
properties. `AIProgress` uses `total` in Swift, `max` in JSON. Table footer keys
match columns; alignment is leading/trailing. Charts need unique stable row labels
and numeric values for every series; inspect the schema for limits and supported props.

Use one `@StateObject AIUIStore` per surface and `AIUIRenderer(store:onEvent:)` inside
`AIMessage` or another view. Feed each arriving JSONL byte chunk into `receive` on the
main actor; do not wait for a full document or try to decode incomplete JSON tokens.
For SSE, extract each complete `data:` payload, decode `AIUIStreamEvent`, and call
`apply`; never feed raw SSE headers to `receive`. Call `finish` on JSONL EOF and
inspect session.phase/errorMessage: a syntactically complete stream without
surface.complete still fails. Call `interrupt` on cancel/failure, including errors
from direct `apply`; reset before retrying with a fresh begin. Connect stream
termination to the host network task's cancellation.

Generate begin/update/complete lines incrementally, with stable node IDs and ordered
revisions: after begin, baseRevision equals the current server revision and revision
increments by one. Each update replaces a named whole node; include its
events/bindings/children again. Missing children can render placeholders during
generation but must exist by completion. Initialize state once and avoid overwriting
user drafts during later chart updates. Editable Input/Select/Switch nodes need
bindings.value pointing to initialized state; Switch values must be boolean.
Button needs events.press and an onEvent handler. Action events include only declared
stateKeys, not the whole form automatically. The host dispatches known actions and
can return another update/complete pair after completion; local edits do not advance
server revision. Never evaluate AI-generated code or arbitrary action names.
Persist the completed document, not a partial decoder buffer; restore with load or
AIChatMessage.parts .ui(document) and handle AIChat.onUIEvent. Do not claim OpenAI/A2UI
wire compatibility.

`ui validate` accepts complete documents or successful complete/removed JSONL streams,
not unfinished fragments; it checks runtime semantics as well as JSON syntax.
Verify partial rendering,
UTF-8 splitting, interruption/retry, form edits during streaming, and iOS/macOS
light/dark behavior. Preserve iOS 44 pt targets. Current foundation catalog has
15 types; inspect the schema before promising any unsupported shadcn variant.
For visual work, use `Documentation/Foundation-Visual-Validation.md`: default-state
same-width evidence covers both themes/platforms, not every interaction or device.
