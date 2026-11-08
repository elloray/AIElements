---
name: AIElements for SwiftUI
description: Native reproduction of the shadcn/ui AI Elements reference visual system.
colors:
  light-background: "rgb(100% 100% 100%)"
  light-foreground: "rgb(0% 0% 0%)"
  light-muted: "rgb(96.0587% 96.0587% 96.0587%)"
  light-muted-foreground: "rgb(45.1519% 45.1519% 45.1519%)"
  light-border: "rgb(89.8161% 89.8161% 89.8161%)"
  light-destructive: "rgb(90.6411% 0% 4.2121%)"
  dark-background: "rgb(3.9388% 3.9388% 3.9388%)"
  dark-foreground: "rgb(98.0256% 98.0256% 98.0256%)"
  dark-muted: "rgb(14.9382% 14.9382% 14.9382%)"
  dark-muted-foreground: "rgb(63.0163% 63.0163% 63.0163%)"
  dark-border: "rgb(100% 100% 100% / 10%)"
  dark-destructive: "rgb(100% 39.1179% 40.3845%)"
  light-input: "rgb(89.8161% 89.8161% 89.8161% / 50%)"
  dark-input: "rgb(100% 100% 100% / 7.5%)"
  dark-accent: "rgb(25.0471% 25.0471% 25.0471%)"
typography:
  body:
    fontFamily: Geist
    fontSize: "14pt"
    fontWeight: 400
  title:
    fontFamily: Geist
    fontSize: "14pt"
    fontWeight: 500
  label:
    fontFamily: Geist
    fontSize: "12pt"
    fontWeight: 500
  code:
    fontFamily: Geist Mono
    fontSize: "12pt"
    fontWeight: 400
  metadata:
    fontFamily: Geist
    fontSize: "10pt"
    fontWeight: 400
rounded:
  option: "6pt"
  attachment: "8pt"
  surface: "14pt"
  prompt: "18pt"
  message: "22pt"
spacing:
  detail: "2pt"
  tight: "4pt"
  control: "6pt"
  row: "8pt"
  compact-inset: "10pt"
  panel: "12pt"
  content: "16pt"
components:
  button-primary:
    backgroundColor: "{colors.light-foreground}"
    textColor: "{colors.light-background}"
    typography: "{typography.title}"
    padding: "6pt 12pt"
  button-outline:
    textColor: "{colors.light-foreground}"
    typography: "{typography.title}"
    padding: "6pt 12pt"
  button-ghost:
    textColor: "{colors.light-foreground}"
    typography: "{typography.title}"
    padding: "6pt 12pt"
  button-secondary:
    backgroundColor: "{colors.light-muted}"
    textColor: "{colors.light-foreground}"
    typography: "{typography.title}"
    padding: "6pt 12pt"
  badge:
    backgroundColor: "{colors.light-muted}"
    textColor: "{colors.light-foreground}"
    typography: "{typography.label}"
    padding: "3pt 8pt"
  prompt-input:
    textColor: "{colors.light-foreground}"
    typography: "{typography.body}"
    rounded: "{rounded.prompt}"
    padding: "12pt"
  model-selector:
    textColor: "{colors.light-muted-foreground}"
    typography: "{typography.body}"
    padding: "0pt 12pt"
  code-block:
    backgroundColor: "{colors.light-muted}"
    textColor: "{colors.light-foreground}"
    typography: "{typography.code}"
    rounded: "{rounded.surface}"
    padding: "12pt"
  trace:
    textColor: "{colors.light-muted-foreground}"
    typography: "{typography.body}"
---
# Design System: AIElements for SwiftUI

## Overview

**Creative North Star: "The AI Elements Reference"**

The visual authority is the shadcn/ui AI Elements reference captured in `Reference/` on 2026-11-05, with computed CSS tokens measured on 2026-11-06 in `Reference/visual-tokens.json`. Preserve its quiet neutral surfaces, compact Geist typography, Lucide line icons, pill controls, and connected activity traces across the 21 native patterns. This is a code-led transcription of an established visual system, not a new identity.

SwiftUI supplies native input, popovers, accessibility, and adaptive layout on iOS 17+ and macOS 14+. The intended fidelity is close to the reference; native font rasterization and platform chrome differ, and no complete browser-to-native pixel equivalence certification has been performed.

**Key Characteristics:**

- Neutral light and dark appearances with restrained destructive color.
- Bundled Geist / Geist Mono and native Lucide paths.
- Compact visible controls with platform-appropriate interaction space.
- Flat tonal surfaces and thin trace connectors.

## Colors

The palette is grayscale, with destructive red reserved for failure. Primary actions invert foreground and background; they do not introduce a brand accent. Light and dark primitives are exact percentage transcriptions of SwiftUI `Color` channel values from `Sources/AIElements/Theme.swift`, preserving precision instead of rounding to 8-bit hex. Translucent colors composite with the host surface.

### Primary

`foreground` is the high-contrast primary action fill; `background` becomes its label color. Theme overrides use the same semantic mapping.

### Neutral

`background` is the host-facing canvas, `muted` supplies code surfaces, attachments and user messages, and `mutedForeground` supplies trace text and supporting labels. `border` defines outlines and thin connectors. The prompt uses the dedicated inputBackground token; dark borders are translucent rather than an opaque gray.

**The Semantic Theme Rule.** Resolve component colors through `AITheme`; do not hard-code a light appearance into a new native component. Frontmatter component color references describe the light variant; dark uses the corresponding dark primitives.

## Typography

Geist is the body and control face; Geist Mono is the code face. Font files live in `Sources/AIElements/Resources/Fonts/`; `AITypography` in `Theme.swift` registers them with CoreText and selects Regular, Medium, or SemiBold. The helper maps both requested bold and semibold to SemiBold. No global UIAppearance changes are made.

The frontmatter records base point sizes. Body and title share a size but differ in weight. Labels support compact controls; metadata appears on attachment file sizes. Markdown headings in `Markdown.swift` use `max(16, 26 - level * 2)` with semibold. Body Markdown and code use additional line spacing (4pt); no universal fixed line-height or tracking token exists.

**The Native Scaling Rule.** `Font.custom(..., relativeTo: .body)` must remain Dynamic Type aware. Preserve multiline labels and vertical growth; do not turn base point sizes into a fixed raster layout.

## Layout

`AITrace` in `Sources/AIElements/Trace.swift` is the shared leading-aligned vertical activity layout. Its gap uses the row spacing token. Expanded children receive leading content padding, a thin border-colored connector (1pt), an additional leading offset (7pt), top spacing (8pt), and bottom margin (4pt). The connector follows only the content height. Disclosure content stays mounted while collapsed, with hit testing and accessibility disabled.

`AIControlDensity` in `Theme.swift` defaults to `.comfortable` on iOS and `.reference` on macOS. Comfortable mode supplies a minimum independent interaction frame (44 × 44pt) while preserving the compact visible shape. `.aiControlDensity(.reference)` explicitly requests the reference's compact spacing. This is an intentional native adaptation, not a claim that iOS default spacing is pixel-identical to the website.

Prompt controls use `ViewThatFits` to move from one horizontal toolbar to a stacked layout when space runs out. `AIModelSelector` stacks at accessibility text sizes. There are no global CSS-style breakpoints. Confirmation similarly adapts between horizontal and vertical compositions. Checkpoint labels have layout priority over decorative divider lines and may wrap (`ActionsAndSources.swift`).

Dimensions in this file are SwiftUI points. A browser preview maps these numeric dimensions to CSS pixels for illustration only; CSS `pt` is not a device-pixel equivalence rule.

## Elevation & Depth

Library components are flat: no custom shadow vocabulary is implemented. Tonal fills, thin outlines, indented traces, and disclosure state establish hierarchy. Native popovers may carry system-managed elevation; do not copy that platform chrome into the library token set.

Motion is limited and functional. Disclosure uses ease-out (0.2 seconds), disabled when Reduce Motion is active. Running traces use a two-second shimmer cycle at up to 30 updates per second; Reduce Motion, hidden disclosures, background scenes and `.aiAnimationsEnabled(false)` pause it. `AICopyButton` restores its copy icon after two seconds. These extensions are recorded in the sidecar rather than the frontmatter.

## Shapes

The frontmatter radius scale comes from `Theme.swift`, `PromptInput.swift`, and `Message.swift`. The theme surface radius is configurable; prompt, message, attachment, and option radii are component-specific. Buttons, badges, and model-selector labels use SwiftUI `Capsule`, whose fully rounded geometry is content-dependent rather than a fixed radius token. Borders are thin (1pt).

`Sources/AIElements/Icons.swift` contains 39 Lucide icons as native paths on a 24-unit coordinate grid. The default rendered size is 16pt; component-specific sizes include 12pt and 14pt. Stroke width is `size / 12`, equivalent to Lucide's 2-unit stroke before scaling, with round caps and joins. Decorative paths are hidden from accessibility; their containing controls supply labels.

## Components

### Buttons

`AIButtonStyle` in `Theme.swift` provides primary, outline, ghost, and secondary variants. All use Capsule geometry; outline uses the semantic border, secondary uses muted fill, and primary uses inverse foreground/background. Regular and icon controls are 32pt, small controls 28pt, tiny controls 24pt before Dynamic Type scaling. Tiny controls use 12pt type and 10pt horizontal padding; other text controls use 14pt and 12pt padding. Icon controls are square. Pressed opacity is 0.75 and disabled opacity is 0.5. Nonprimary pressed or hovered controls use muted fill; keyboard focus uses a 2pt muted-foreground outline.

### Chips

`AIBadge` uses muted fill and Capsule geometry. It is informational, with no invented hover or selected state. `AIAttachmentView` is an outlined muted tile with an image preview or file icon, filename, optional size, and independently labeled remove control (`PromptInput.swift`).

### Cards / Containers

`AICodeBlock` uses muted fill and theme surface radius, a padded optional language/copy header, selectable monospaced content, and an optional line-number gutter. The default maximum content height is 256pt. `AIConfirmation` uses an outlined surface and adaptive action group. Both reuse tokens rather than introducing shadow effects (`CodeAndTools.swift`, `ActionsAndSources.swift`).

### Inputs / Fields

`AIPromptInput` in `PromptInput.swift` wraps a multiline plain text field, attachments, model/effort selection and send/stop controls. It uses an 18pt radius, 12pt panel inset and the dedicated inputBackground token. The unfocused border is transparent; focus draws a 2pt muted-foreground border at 0.6 opacity. An AppKit/UIKit text editor grows within bounded height. Empty submissions disable send, submitted requests show a spinner, and streaming requests show stop. macOS Enter sends and Shift+Enter inserts a newline; composition is preserved. iOS software-keyboard Return inserts a newline, while hardware Enter sends. Submission acceptance and clearing belong to the host; attachmentResetID resets internally owned attachments after acceptance.

### Navigation

The library does not impose app-level navigation. `AIModelSelector` is an inline pair of capsule triggers with 14pt type and 32pt minimum height. macOS uses NSMenu and iOS uses Menu, preserving system keyboard and selection behavior. Selected items display checkmarks; options are grouped by provider. Host navigation remains outside the reference token system.

### Activity Traces and Messages

`AITraceLine` combines a Lucide status icon, title, and optional detail with muted text; failures use destructive color and pending rows use opacity 0.6. `AITraceDisclosure` adds a rotating chevron and nested connector. Tool, Terminal, Reasoning, Task, Plan, Queue, Subagent, Sources, Test Results, and related patterns compose these primitives.

`AIMessage` in `Message.swift` aligns user content right on a rounded muted bubble and assistant content left on the canvas. User messages use horizontal inset (12pt), vertical inset (10pt), and a maximum width of 80% of the available conversation width. Optional footer actions sit outside the bubble. Actions remain individually labeled. Use stable model identifiers to preserve disclosure and feedback state during streaming updates.

## Do's and Don'ts

### Do:

- Do use `AITheme`, `AITypography`, `AIIcon`, and `AIButtonStyle` when composing new patterns.
- Do retain the default iOS comfortable interaction density and test explicit reference density separately.
- Do verify light, dark, narrow, wide, and accessibility text layouts with native renders.
- Do preserve host ownership of submission, cancellation, approval, and restoration callbacks.
- Do use the dated `Reference/` snapshots to resolve visual questions before extending the system.

### Don't:

- Don't replace Geist with the system face or Lucide with SF Symbol approximations inside the reference components.
- Don't add decorative brand colors, shadows, or large display typography without a new explicit design decision.
- Don't mistake sidecar HTML previews for native screenshots or pixel-equivalence evidence.
- Don't enforce fixed row heights that clip Dynamic Type text or collapse independent touch targets.


### November 7 visual refinements

The 360pt Chat composer uses `compact: true`: 24pt editor line boxes, 9pt top inset, and an independent 44pt toolbar on iOS. Standard inputs retain the 112pt empty state. Choice menus use 16pt chevrons, medium text, and an 8pt gap between the effort prefix and value. Approval cards use 15pt horizontal / 13pt vertical insets, a 14pt gap, and 19.25pt title line boxes. Citation labels use Geist Medium at 12pt with 11pt inset.

On macOS, native paragraph, citation and prompt text draws without AppKit font smoothing, matching the web reference’s antialiased treatment without changing weights or global application preferences. Visible capsule layers are clipped before the separate touch rectangle is applied; this also prevents offscreen capture corner artifacts. Terminal triangles and hollow circles follow the original webfont’s Arial fallback at 134.59% size; styled soft wrapping retains per-run attributes and copies the untouched source.


### November 8 text rendering refinements

`AITextLabel` draws noneditable labels with their original Geist face and metrics. On macOS its local AppKit draw context disables font smoothing; it does not lower font weight or change global preferences. The containing SwiftUI button still owns pointer events, focus, pressed/disabled states and its 44pt iOS target. Plain label accessibility is static text. Selectable paragraphs and code remain native text views. The label is also available to hosts composing custom `AIButtonStyle` controls; a plain SwiftUI `Text` keeps platform rendering.

iOS prompt editors explicitly use TextKit 1: a positive baseline offset does not alter the 24pt line-fragment rhythm. Chat's empty-description glyphs receive a scaled 3pt optical offset, preserving the title and icon geometry. Inline citation body glyphs use a scaled 3pt baseline adjustment independently of the attachment; the original capsule geometry, link hit testing and text selection remain native.

### November 8 focused typography refinement

On macOS, `AITextLabel` disables AppKit's default tightening before truncation so long trace titles keep the reference's character spacing and ellipsis position. Intrinsic widths round outwards to a backing pixel; short labels must not acquire an ellipsis from fractional width rounding. The complete string remains the accessibility label.

On iOS, cited-text attachments use a scaled 3pt descent adjustment, keeping mixed text/attachment line fragments at 24pt instead of 24.61pt at the default size. Terminal code's TextKit delegate enforces the specified maximum line height even when enlarged fallback symbols are present, without changing the underlying text or glyph baseline. The 360pt fixture now uses consistent 19.5pt code lines. Touch targets and scroll behavior stay native.
