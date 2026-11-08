# Streaming UI protocol 1.0

AIElements streams a native interface into a conversation. A title/card can appear
before its children; inputs remain editable while chart data arrives. This is an
independent protocol, not OpenAI Intelligent UI, A2UI, or json-render wire compatibility.
The host owns inference, transport, persistence, and business actions. No generated
Swift, HTML, JavaScript, URLs, or shell commands are evaluated by the renderer.

## Quick start

```swift
import SwiftUI
import AIElements

struct StreamingReport: View {
    @StateObject private var store = AIUIStore()

    var body: some View {
        AIMessage(role: .assistant) {
            AIUIRenderer(store: store) { event in
                // Route a known action to your host app/service.
                // event.state contains only the keys declared by stateKeys.
                print(event.name, event.state)
            }
        }
    }
    // Call on the main actor as each transport chunk arrives:
    @MainActor func receive(_ bytes: Data) throws { try store.receive(bytes) }
    @MainActor func finished() throws { try store.finish() }
    @MainActor func failed(_ error: Error) { store.interrupt(error.localizedDescription) }
}
```

`AIUIStore` is MainActor-isolated. Await it from a background transport task; do not
buffer the entire response before calling `receive`. One store represents one surface.
On cancellation/network failure call `interrupt`; before retry call `reset` and stream
a fresh `surface.begin`. Persist `store.session.document` after completion. Restore it
with `load(document)`, or put `.ui(document)` in `AIChatMessage.parts` and handle
`AIChat(onUIEvent:)`. For a live message, embed the store-backed renderer in `AIMessage`.

Use the `AIElementsUIProtocol` SwiftPM product alone for Foundation-only producers,
validators, or tests. `import AIElements` also exposes the protocol types.

## Transport and lifecycle

UTF-8 JSONL: **one complete JSON event per line**. Model tokens/network chunks may
split anywhere, even in a Chinese character; the decoder buffers until a whole line.
Generate small events as content becomes available, instead of one final document.
The schema describes each line, not an incomplete JSON token prefix. With SSE, extract
and decode the `data:` payload as `AIUIStreamEvent`, then `try store.apply(event)`;
do not pass raw SSE headers to the JSONL decoder. WebSocket messages can be decoded
and applied the same way. On errors from direct `apply`, call `interrupt` in the host.

```jsonl
{"version":"1.0","kind":"surface.begin","surfaceID":"answer","revision":0,"root":"card","nodes":{"card":{"type":"Card","props":{"title":"Visitors"},"children":["chart"]}}}
{"version":"1.0","kind":"surface.update","surfaceID":"answer","baseRevision":0,"revision":1,"nodes":{"chart":{"type":"BarChart","props":{"series":[{"key":"visitors","label":"Visitors"}],"data":[{"label":"January","visitors":186}]}}}}
{"version":"1.0","kind":"surface.update","surfaceID":"answer","baseRevision":1,"revision":2,"nodes":{"chart":{"type":"BarChart","props":{"series":[{"key":"visitors","label":"Visitors"}],"data":[{"label":"January","visitors":186},{"label":"February","visitors":305}]}}}}
{"version":"1.0","kind":"surface.complete","surfaceID":"answer","baseRevision":2,"revision":3}
```

| Event | Meaning |
| --- | --- |
| `surface.begin` | Creates a surface. Required `root`; optional initial `nodes` and `state`. |
| `surface.update` | Upserts whole nodes by stable ID, merges explicitly included state keys, optionally changes root or removes `removeNodes`. |
| `surface.complete` | Applies an optional final patch and validates all references/bindings. |
| `surface.error` | Freezes the last valid interface and shows `message`; retry starts a new session. |
| `surface.remove` | Removes a surface, including a failed one. |

All events use `version: "1.0"`, `surfaceID`, nonnegative `revision`. After begin,
`baseRevision` must match the current server revision and `revision = baseRevision + 1`.
Duplicate, skipped, and misrouted frames are rejected atomically; the host requests a
fresh snapshot rather than silently reordering them. A completed surface can receive
a later update/complete pair (for a user interaction response). Local input changes
do not advance the server revision. `finish()` freezes an unfinished stream, retaining
its rendered content; inspect `session.phase`/`errorMessage` as well as decoding errors.

Missing referenced children render placeholders during generation. Completion rejects
missing references, cycles, multiple parents, invalid values, and unknown component
types/properties. Use stable node IDs and stable chart row labels to preserve identity.
`nodes` replaces each named **whole node**; include its bindings/events/children again.
Only fields included in `state` are replaced. Do not resend initial form values with
every chart patch: that explicitly overwrites user edits. For concurrent backend edits,
the host must resolve conflicts; this version has no CRDT or automatic reconnect.

## Component catalog

This release adds 15 protocol types, alongside the existing 21 AI Elements patterns.
It does **not** implement every shadcn component or every chart variant.

| Types | Properties |
| --- | --- |
| `Stack`, `Row` | `gap`; `children` IDs (`Row` wraps vertically when needed) |
| `Card` | `style: standard/chart` (default standard), `title`, `description`, `footer`, `footerIcon: "trending-up"`, `footnote`; `children` IDs |
| `Text` | `text`, `variant`: body/title/muted/caption/label |
| `Button` | `label`, `variant`, `disabled`; `events.press` |
| `Badge` | `text`, `variant` |
| `Input` | `label`, `placeholder`, `value`, `disabled`; `bindings.value`, `events.change` |
| `Select` | `label`, `placeholder`, `options: [{value,label}]`, `value`, `disabled`; binding/change |
| `Switch` | `label`, boolean `value`, `disabled`; binding/change |
| `Progress` | `label`, numeric `value`, positive `max` |
| `Separator` | No properties |
| `Table` | `columns: [{key,label,width?,alignment?,emphasized?}]`, `rows: [{key:value}]`, `footer: {key:value}`, `caption` |
| `BarChart`, `LineChart`, `AreaChart` | `label`, `series: [{key,label}]`, `data: [{label,key:number}]`, `height`, `legend`; `events.select` |

Variant values for Button/Badge: `primary`, `secondary`, `outline`, `ghost`, `destructive`.
Charts support up to five series and 200 rows, signed values, empty/loading data,
tap/hover tooltips and VoiceOver value navigation. Line/area use natural cubic
curves; Area uses the reference solid fill at 40% opacity. Stacked, pie, radar,
and zoom variants are not implemented.
Native controls use the shadcn geometry/tokens, with iOS interactive areas at least
44 pt. Native text rasterization, native menus, and Dynamic Type differ from the web.

`AICard` defaults to the current base-component geometry (16 pt insets). Use
`style: .chart` / JSON `"style": "chart"` for the chart gallery's 25 pt inset including
its border. Bundled chart/dashboard documents explicitly select that style.
The native Card API also accepts `headerAction` and `footerContent` views; native
`AIInput` supports secure entry and a label accessory. These composition slots are
SwiftUI APIs, not additional executable actions in the JSON protocol.

Table column alignment accepts `leading` or `trailing`; optional widths are preferred
widths (24...600 pt). Content may widen the table and scroll rather than truncate.
Footer values use column keys. Select's placeholder appears when its bound value is
empty. `Text`'s `label` variant uses 14 pt medium text with a compact line box.

[15-component same-width light/dark comparison](Foundation-Visual-Validation.md).

Read the executable schema for precise permitted properties and bounds:

```sh
./aielements ui schema
./aielements ui example dashboard > /tmp/dashboard.json
./aielements ui stream > /tmp/dashboard.jsonl
./aielements ui validate /tmp/dashboard.json
./aielements ui validate /tmp/dashboard.jsonl --json
```

`ui schema/example/stream` emit the raw protocol artifact (even with `--json`). Other
CLI JSON output retains its CLI envelope. `ui validate` checks runtime semantics too;
JSON Schema alone does not detect graph cycles, missing references, or revision gaps.

## State and action round trip

Bind controls to flat state keys, separate from node presentation:

```json
{
  "type": "Input",
  "props": {"label": "Report name"},
  "bindings": {"value": "reportName"},
  "events": {"change": {"name": "rename_report", "stateKeys": ["reportName"]}}
}
```

The host receives `AIUIEvent` with event ID, protocol version, surface ID/revision,
node ID, action `name`, event kind, value, declared payload, and only the opted-in
`stateKeys`. Inputs update local state immediately. Button actions require a host
callback. Dispatch only known actions; validate their payload and permissions in your
service. Return fresh surface updates for subsequent model output. The library never
performs an action merely because an AI supplied its name.

## Producer guidance for AI coding tools

1. Read the schema and one example. Use only catalog types and valid props.
2. Emit `surface.begin` as soon as the initial layout/title is known.
3. Stream small `surface.update` lines: text, controls, then chart/table data as ready.
4. Initialize bound state once; keep IDs stable and send only changed nodes/state keys.
5. End with `surface.complete`. On failure, send `surface.error` when transport allows.
6. Test fragmented UTF-8, cancellation, invalid frames, ordering, local edits, and both platforms.

## References and attribution

Visual references: [shadcn/ui components](https://ui.shadcn.com/docs/components),
[bar chart gallery](https://ui.shadcn.com/charts/bar), and its
[new-york-v4 chart example](https://ui.shadcn.com/view/new-york-v4/chart-bar-default).
Original shadcn/ui work is MIT licensed; see [THIRD_PARTY_NOTICES](../THIRD_PARTY_NOTICES.md).
Concept research: [OpenAI Intelligent UI announcement](https://openai.com/index/gpt-6-for-everyone/),
[json-render streaming](https://json-render.dev/docs/streaming), and
[A2UI](https://a2ui.org/specification/v0.9-a2ui/). These links explain related approaches;
AIElements does not claim their affiliation, proprietary implementation, or protocol compatibility.
