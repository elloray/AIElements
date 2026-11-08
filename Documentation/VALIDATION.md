# Validation

## CLI and Skill pass — 2026-11-08

- `swift test`: **29 component tests + 8 CLI tests** passed on macOS.
- `python3 Scripts/validate-cli.py --ios`: all **21 shipped CLI examples** and the
  generated consumer package compiled on macOS and for iOS Simulator (arm64 and x86_64).
  Also verified JSON/error exit contracts, a local dependency path with spaces and
  quotes, remote revision manifest parsing, and project Skill installation.
- Release CLI installed into a separate prefix and ran after relocation, including
  a path with spaces; confirmed it read the relocated resource bundle. Reinstall
  refused to overwrite the existing installation.
- Skill frontmatter passed the skill-creator validator. Codex/Claude Code skill
  folders were generated and checked; automatic invocation inside those clients
  was not exercised as an end-to-end client test.

This pass adds developer tooling only. It does not claim a new simulator UI run or
repeat of the screenshots below. Commands and maintenance notes: [CLI guide](CLI.md).

## Latest focused pass — 2026-11-08

- Environment: iPhone 17 Pro simulator, iOS 27.0; macOS 27.0.1.
- Package tests: **iOS 30**, **macOS 29**, zero failures.
- Targeted iOS UI tests: **8** passing cases across light and dark mode. Covers citation previews, File Tree and Stack Trace 44 pt targets and callbacks, and Terminal scrolling and disclosure.
- macOS actual-window checks: Stack Trace callbacks and collapse/expand, readable Terminal output, and complete File Tree labels and file selection in dark mode.
- Visual checks: 21 default examples plus an approval state, both appearances, Web / iOS / macOS at 360 CSS px / pt and 2×. Native screenshots were rebuilt after the changes; the immediately preceding live Web baseline was retained.

The final refinement disables macOS automatic letter tightening before truncation, prevents short labels from truncating after pixel rounding, reduces iOS citation line-height accumulation, and keeps terminal code lines at 19.5 pt when larger fallback glyphs appear.

The comparison previews in `Images/` are evidence of representative states, not a claim of full pixel identity. On iOS, the visible citation height remains approximately 0.5 pt taller in light mode and 1 pt taller in dark mode. Some code glyphs and clipping edges retain platform differences. Independent 44 pt controls deliberately create taller lists.

## Reproduce

Run package tests on macOS:

```bash
swift test
```

Run package tests on an available simulator, replacing the destination with one installed on your machine:

```bash
xcodebuild -scheme AIElements-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Build or run the example Xcode project using the instructions in the root README. Generate the gallery's reference and state screenshots with:

```bash
swift run AIElementsGallery --snapshots
```

Package tests are versioned in `Tests/`. The local acceptance runner used for the targeted UI checks is not a shipped package target. Build caches, historical visual-comparison runs and machine-specific logs are excluded from Git.

## Limits

Deployment targets are iOS / iPadOS 17+ and macOS 14+. The latest pass does not establish behavior on every older supported OS, physical device, VoiceOver flow, animation or hover state. macOS actual-window checks are not represented as a complete XCUITest suite. Examples use local demonstration data and do not execute commands or invoke a model service.
