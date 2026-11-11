# Android direction contract

Mode: Operate. The requested replica preserves the current AIElements visual authority.

THESIS: Reusable native Compose equivalents of the existing SwiftUI patterns and streaming UI.
OWN-WORLD: Existing neutral light/dark tokens, bundled Geist and Geist Mono, the same Lucide paths, flat surfaces, compact visible controls inside independent 48 dp targets.
STORY: Browse a searchable component catalog, inspect and interact with a local example, then embed the matching public composable in a host application.
FIRST VIEWPORT: A system-inset app bar with title and appearance menu; searchable categorized catalog on phones; catalog alongside detail on wide screens. Detail shows the pattern, local-demo label and working controls.
FORM: User-pinned replica, no new visual direction. Streaming nodes appear progressively using the same JSONL resources as Swift.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## 2026-11-11 refinement rules

- A card spaces its header, body and footer. Body layouts own their internal spacing; JSON cards explicitly retain their 16 dp spacing (24 dp for charts).
- `AIChatHeader` uses a 16/24 title, a 4 dp title/description gap and a separate 48 dp reset action. Omit this heading in short landscape panes. The empty-state title uses 18/28 with tight tracking; the description uses 14/22.75.
- Expanded trace prose uses 14/22.75; a blank paragraph line scales with the system font size. Tool/code text keeps its own typography.
- Link-style field actions align text to the field edge while retaining a separate 48 dp target. Card footer padding can be reduced without shrinking or overlapping button targets.
- Approval panels place their actions below the description when inner width is below 320 dp or font scale exceeds 1.2; wider panels center actions vertically.
- Every published comparison preserves natural height at 360 CSS px / 360 dp. List density and action-bar spacing differences remain explicit; visual parity does not justify overlapping touch regions.
- Native viewport capture checks the foreground window as well as process liveness. Screenshots obstructed by system dialogs are rejected.

## 2026-11-11 precision pass

- Icon buttons can align their visible surface within the existing independent 48 dp target. `AIChatHeader` uses top/end alignment; other icon buttons retain centered visuals by default.
- Tables measure each cell with its rendered font weight and distribute surplus width in proportion to content width. Shared separators are drawn within rows instead of contributing separately rounded layout height.
- Table rows use 40 dp headers, 37 dp body rows and 36.5 dp footers as minimums. Large text may increase these heights; wide content remains horizontally scrollable.
- Website references must show the final progress/animation state. Verify the actual theme after hydration and flush visible rendering before saving chart screenshots.

## Form surface alignment — fourth pass, 2026-11-11

- Dark form fill is white at 4.5% alpha (`input` white 15% × `dark:bg-input/30`), verified against the website’s settled computed styles. Input borders remain white at 15%.
- Compose draws borders inside layout bounds. Input content starts 11 dp from the outer edge; Select uses start 11 / end 9 dp with a 6 dp content-to-chevron gap, matching the website’s 1 px border plus 10 / 8 px padding.
- Visible fields remain at least 32 dp high inside independent 48 dp interactive areas. Theme color changes apply to the shared public components, including embedded forms.
- Capture theme transitions before judging color: wait for the target’s computed styles and chart geometry to settle, and use document coordinates for scrolled-page crops.
