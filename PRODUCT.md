# AIElements Swift
<!-- impeccable:product-schema 1 -->
## Platform
ios

Also macOS; both platforms explicitly confirmed by the user. Android native replica requested on 2026-11-10, implemented separately under Android/. HarmonyOS NEXT is implemented under HarmonyOS/.
## Stack
Swift requested by user; SwiftUI and Swift Package Manager selected for native reuse.

Android: Kotlin, Jetpack Compose, Gradle; reusable Compose library, pure Kotlin protocol module, and local example gallery. Android API 26+, with shared JSON protocol fixtures and the existing visual identity.

HarmonyOS: ArkTS, ArkUI, Stage model, API 12+, with a reusable HAR and a local gallery using the shared JSONL fixtures.
## Users
Developers embedding native AI interfaces in Apple, Android, or HarmonyOS apps.
## Product Purpose
Make every shadcn/ui component and AI Elements pattern available as a reusable native control on Apple, Android, and HarmonyOS.
## Capabilities and Constraints
The 21 AI Elements patterns listed on 2026-11-05 define the original chat-component scope. The 2026-11-08 extension adds streaming generative UI with 15 catalog node types, including native forms and bar/line/area charts. The native shadcn catalog adds all 67 entries from the 2026-11-28 official index, each with an interactive example. The streaming adapter supports its original 15 JSONL node types. iOS 17+ and macOS 14+. No model provider dependency. Host owns networking, execution, persistence and approval decisions. Gallery uses clearly labeled local demo data.
## Brand Commitments
User requests pixel-level fidelity to the reference, including Geist, Lucide, neutral colors, spacing, and both appearances. This overrides platform-default font/icon styling. Native navigation and accessibility remain supported.
## Evidence on Hand
Official Markdown snapshots in Reference/; live browser inspection of Tool and Prompt Input. 360 pt bar-chart light/dark comparisons and partial/complete/interrupted native UI captures are available in .impeccable/review/streaming-ui/. Original website is the visual authority; no new visual direction requested.
