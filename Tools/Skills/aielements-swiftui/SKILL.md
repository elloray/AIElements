---
name: aielements-swiftui
description: Build or modify native SwiftUI AI interfaces with the elloray/AIElements library on iOS, iPadOS, and macOS. Use for integrating its chat, prompt input, reasoning summaries, tool output, approvals, citations, and task components. Does not apply to React shadcn projects or model backend implementation alone.
---

# AIElements SwiftUI

Use this package's actual Swift API rather than translating React props. It is an
independent, unofficial port of shadcn/ui AI Elements. Preserve upstream attribution
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
```

`show` includes public symbol names, implementation paths, behavioral notes, the
original design URL, and a complete Swift source example. IDs such as `file-tree`
and symbols such as `AIFileTree` both work. JSON uses `schemaVersion: 1`;
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
