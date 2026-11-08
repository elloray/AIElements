import SwiftUI
import AIElements
#if os(macOS)
import AppKit
#endif

struct DemoView: View {
    let pattern: Pattern
    @Environment(\.aiControlDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiThemeOverride) private var themeOverride
    private var theme: AITheme { themeOverride ?? (colorScheme == .dark ? .dark : .light) }
    private var chatSendColor: Color {
        colorScheme == .dark ? Color(red: 25 / 255, green: 60 / 255, blue: 184 / 255)
                             : Color(red: 0.08, green: 0.28, blue: 0.91)
    }
    @State private var text = ""
    @State private var attachments: [AIAttachment] = []
    @State private var model = "gpt-5"
    @State private var effort = AIEffort.medium
    @State private var showsApproval: Bool
    @State private var decision = AIConfirmationDecision.pending
    @State private var selectedPath: String? = "components/ui/button.tsx"
    @State private var restored = false
    @State private var submissionRevision = 0
    @State private var executionStatus = AIStatus.running
    @State private var executionOutput: String?
    @State private var replaying = false
    @State private var reasoningExpanded = true
    @State private var notice = ""
    @State private var messages: [AIChatMessage] = []
    @State private var streaming = false
    @State private var responseTask: Task<Void, Never>?
    private let models: [AIModel] = [
        .init(id: "gpt-5", name: "GPT-5", provider: "OpenAI"),
        .init(id: "gpt-5-mini", name: "GPT-5 mini", provider: "OpenAI"),
        .init(id: "claude-sonnet", name: "Claude Sonnet", provider: "Anthropic")
    ]
    private let sources = [
        AISource(title: "Install Astro | docs.astro.build", url: URL(string: "https://docs.astro.build/en/install-and-setup/")!),
        AISource(title: "create-astro | npmjs.com", url: URL(string: "https://www.npmjs.com/package/create-astro")!),
        AISource(title: "pnpm create | pnpm.io", url: URL(string: "https://pnpm.io/cli/create")!)
    ]
    private let steps: [AIStep] = [
        .init(id: "install", title: "Install @base-ui/react"),
        .init(id: "imports", title: "Replace the Radix imports"),
        .init(id: "render", title: "Rename asChild to render"),
        .init(id: "types", title: "Run the type checker")
    ]
    private static let chatPrompts = ["Add a dark mode toggle to the settings page.", "Make it follow the system setting by default.", "Run the build before I ship it."]
    private static let messageReply = "Install Dialog, then open it from the gear button in `site-header.tsx`.\n\n```bash\nnpx shadcn@latest add dialog\n```\n\nWrap the button in a `DialogTrigger` and put the settings form in `DialogContent`. Focus moves into the dialog when it opens, and **Esc** closes it."
    private static let suggestionReplies: [String: String] = [
        "Add a dark mode toggle": "Added a ModeToggle to the site header. It calls setTheme from next-themes.",
        "Fix the failing build": "The build failed on a missing import in app/page.tsx. I added it and the build passes.",
        "Write tests for the form": "Added four tests in signup-form.test.tsx. They cover the empty, invalid and valid states.",
        "Upgrade to Next.js 16": "Ran the codemod and bumped next to 16. Two routes needed async params, so I updated them.",
        "Add a loading state": "Added a loading.tsx to the dashboard route. It shows skeletons while the data loads.",
        "Find unused dependencies": "Three packages are not imported anywhere: lodash, moment and classnames. Should I remove them?",
    ]
    init(pattern: Pattern, showsApproval: Bool = false) {
        _showsApproval = State(initialValue: showsApproval)
        self.pattern = pattern
        _text = State(initialValue: pattern == .chat ? Self.chatPrompts[0] : "")
    }
    private var previewWidth: CGFloat {
        switch pattern {
        case .chat: 638
        case .promptInput, .modelSelector, .suggestion: 512
        case .message: 448
        case .fileTree: 320
        default: 384
        }
    }
    private var sectionSpacing: CGFloat {
        guard density == .comfortable else { return pattern == .message ? 32 : 16 }
        switch pattern {
        case .message: return 24
        case .checkpoint: return 12
        case .stackTrace, .subagent, .task, .terminal, .testResults, .tool: return 4
        default: return 8
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            component
            if !notice.isEmpty { Text(notice).font(AITypography.font(12)).foregroundStyle(theme.mutedForeground).accessibilityLabel("Result: \(notice)") }
        }.frame(maxWidth: previewWidth, minHeight: pattern == .chainOfThought || pattern == .confirmation ? (density == .comfortable ? 248 : 240) : nil, alignment: pattern == .confirmation && !showsApproval ? .bottomLeading : .topLeading)
            .onDisappear { responseTask?.cancel() }
    }
    @ViewBuilder private var component: some View {
        switch pattern {
        case .generativeUI: GenerativeDemo()
        case .barChart: FoundationChartDemo()
        case .lineChart: FoundationChartDemo(kind: .line)
        case .areaChart: FoundationChartDemo(kind: .area)
        case .chainOfThought:
            question("Why is the checkout deploy so slow?")
            AIChainOfThought(steps: [
                .init(id: "log", title: replaying ? "Reading the build log for dpl_8Kx2" : "Read the build log for dpl_8Kx2", status: replaying ? .running : .completed, content: .code("install    41s\ncompile    38s\nimages   3m 52s")),
                .init(id: "search", title: "Searched the web for next.js image cache key", content: .sources([.init(url: URL(string: "https://nextjs.org/docs/app/api-reference/components/image")!)])),
                .init(id: "code", title: "Searched the code for cacheKey", content: .code("const cacheKey = process.env.VERCEL_GIT_COMMIT_SHA"))])
            if !replaying { answer("Image optimization takes almost four minutes because its cache key includes the commit hash. Key it on the image directory instead.") }
            Spacer(minLength: 0)
            replayButton
        case .chat:
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        AITextLabel("New Thread", size: 18.9, weight: .medium).frame(minHeight: 33.075)
                        AITextLabel("Ask the agent to change your code.", color: theme.mutedForeground).frame(minHeight: 20)
                    }
                    Spacer()
                    Button {
                        responseTask?.cancel(); messages = []; streaming = false
                        text = Self.chatPrompts[0]; attachments = []; notice = ""
                    } label: { AIIcon(.rotateCw) }
                        .buttonStyle(AIButtonStyle(.outline, size: .icon))
                        .offset(x: density == .comfortable ? 6 : 0, y: density == .comfortable ? -6 : 0)
                        .accessibilityLabel("New thread").disabled(streaming)
                }.padding(.horizontal, 32).padding(.bottom, 16)
                AIChat(messages: messages, isStreaming: streaming, onEdit: { text = $0.text }, onRetry: { message in
                    if let index = messages.firstIndex(where: { $0.id == message.id }), let user = messages[..<index].last(where: { $0.role == .user }) {
                        messages.removeSubrange(index...); streamReply(to: user.text)
                    }
                })
                composer.padding(.horizontal, 32)
            }.padding(.vertical, 32).frame(minHeight: 800, idealHeight: 800)
        case .checkpoint:
            question("Rename the button component to action.")
            answer("Renamed Button to Action in components/ui/button.tsx.")
            AICheckpoint("Button renamed", isEnabled: !restored || !messages.isEmpty) {
                responseTask?.cancel(); streaming = false; messages = []; attachments = []
                restored = true; text = "Update the docs to match."; notice = ""
            }
            if !restored { question("Update the docs to match."); answer("Updated the Button page to say Action.") }
            else { transcript; composer }
        case .confirmation:
            if showsApproval {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        question("Clean up the build folder.")
                        AITraceDisclosure("Thought", icon: .circleCheck) { Text("The build artifacts are in dist. Ask for approval before removing them.") }
                        AIConfirmation("Run rm -rf dist?", description: "The command runs in this project.", decision: $decision, executionStatus: executionStatus, output: executionOutput, toolName: "rm -rf dist", onDecision: { value in
                            guard value == .approved else { return }
                            executionStatus = .running
                            responseTask = Task { @MainActor in
                                do { try await Task.sleep(for: .milliseconds(1200)) } catch { return }
                                executionStatus = .completed; executionOutput = "Demo: removed build artifacts. No command was executed."
                            }
                        })
                    }
                    Spacer(minLength: 16)
                    Button {
                        responseTask?.cancel(); decision = .pending; executionStatus = .running
                        executionOutput = nil; showsApproval = false
                    } label: { AITextLabel("Reset", weight: .medium) }.buttonStyle(AIButtonStyle(.outline, compact: true))
                }.frame(minHeight: density == .comfortable ? 248 : 240, alignment: .topLeading)
            } else {
                Button { showsApproval = true } label: { AITextLabel("Send message", weight: .medium) }.buttonStyle(AIButtonStyle(.outline, compact: true))
            }
        case .context:
            AIContext(.init(input: 8420, output: 1260, reasoning: 980, limit: 128000)).frame(maxWidth: .infinity)
        case .fileTree:
            AIFileTree([
                .init(path: "app", children: [.init(path: "app/layout.tsx"), .init(path: "app/page.tsx")]),
                .init(path: "components", children: [.init(path: "components/ui", children: [.init(path: "components/ui/button.tsx")]), .init(path: "components/login-form.tsx")])
            ], selection: $selectedPath) { notice = "Selected \($0.path)" }
        case .inlineCitation:
            AICitedText([
                .text("Next.js streams a route in chunks, so the page shows up before every request finishes. "),
                .source(.init(title: "Streaming", url: URL(string: "https://nextjs.org/docs/app/building-your-application/routing/loading-ui-and-streaming")!, summary: "How the App Router streams a route to the browser.")),
                .text("\n\nWrap a slow part of the page in a Suspense boundary and React sends the fallback first. When the data resolves, the finished HTML streams into the same response and replaces the fallback, with no extra request from the browser. "),
                .source(.init(title: "Suspense", url: URL(string: "https://react.dev/reference/react/Suspense")!, summary: "Display a fallback until its children have finished loading.")),
                .text(" Server Components help here, because their code never ships to the browser. "),
                .source(.init(title: "Server Components", url: URL(string: "https://react.dev/reference/rsc/server-components")!, summary: "Components that render ahead of time, on the server.")),
                .text("\n\nA loading.tsx file does the same for a whole route segment. "),
                .source(.init(title: "Loading UI", url: URL(string: "https://nextjs.org/docs/app/api-reference/file-conventions/loading")!, summary: "Show an instant loading state for a route segment.")),
                .text(" It all runs over chunked transfer encoding, so there is nothing extra to set up. "),
                .source(.init(title: "Transfer-Encoding", url: URL(string: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding")!, summary: "Send a response as a series of chunks."))
            ])
        case .message:
            AIMessage(role: .user, footerSpacing: density == .comfortable ? 0 : 8) { AIMessageText("How do I add a settings dialog? It should open from the gear icon in the header.") } footer: {
                AIMessageActions(text: "How do I add a settings dialog? It should open from the gear icon in the header.", onEdit: { text = "How do I add a settings dialog? It should open from the gear icon in the header." })
            }
            AIMessage(role: .assistant, footerSpacing: density == .comfortable ? 0 : 8) {
                AIMessageResponse(Self.messageReply)
            } footer: {
                AIMessageActions(text: Self.messageReply, onRetry: { notice = "Retry requested." }, onFeedbackChange: { notice = $0.map { $0 ? "Marked helpful." : "Marked unhelpful." } ?? "Feedback cleared." })
            }
            if !text.isEmpty { composer }
        case .modelSelector: composer
        case .plan:
            question("Migrate the dialog components to Base UI.")
            AIPlan("migrate to Base UI", steps: steps.enumerated().map { index, step in var step = step; step.status = replaying ? (index == 0 ? .running : .pending) : .completed; return step })
            if !replaying { answer("Migrated Dialog and AlertDialog. The type checker passes.") }
            replayButton
        case .promptInput: composer
        case .queue:
            question("Add dark mode to the settings page.")
            AIQueue(items: ["Add a dark variant to the theme tokens", "Read the theme from a cookie", "Add a toggle to the settings page", "Check contrast on the charts"].enumerated().map { index, title in .init(id: String(index), title: title, status: replaying ? (index == 0 ? .running : .pending) : .completed) })
            if !replaying { answer("Dark mode is in. The toggle is under Settings, Appearance.") }
            replayButton
        case .reasoning:
            question("Why is the checkout deploy so slow?")
            AIReasoning("The deploy log has three phases. Install takes 38s and next build takes 52s, both normal for this repo.\n\nImage optimization takes 3m 50s. It reruns on every deploy because its cache key includes the commit hash, so the cache never hits.", isStreaming: replaying, duration: 5, isExpanded: $reasoningExpanded)
            if !replaying { answer("Image optimization is the bottleneck. Key its cache on the lockfile and the image directory instead of the commit hash, and the deploy should take under two minutes.") }
            replayButton
        case .sources:
            question("How do I start an Astro project with pnpm?")
            answer("Run pnpm create astro@latest and follow the prompts. It scaffolds the project and installs the dependencies.")
            VStack(alignment: .leading, spacing: density == .comfortable ? 0 : 16) {
                AISources(sources, defaultOpen: true)
                replayButton
            }
        case .stackTrace:
            question("Reset the database and seed it.")
            AITrace {
                AITool("pnpm prisma migrate reset --skip-seed", output: "Database reset.")
                AIStackTrace("TypeError: Cannot read properties of undefined (reading 'email')\n    at seedUsers (prisma/seed.ts:27:18)\n    at main (prisma/seed.ts:51:9)\n    at process (node_modules/server/index.js:89:3)\n    at run (node_modules/tsx/index.js:19:5)\n    at handle (node:internal/modules/cjs/loader:12:3)\n    at launch (node:internal/main/run_main_module:18:5)", defaultOpen: true, onOpenFrame: { notice = "Open \($0.file ?? "unknown"):\($0.line ?? 0)" })
            }
            answer("The migrations ran, but the seed failed in seedUsers. One fixture has no profile, so profile.email is undefined.")
            replayButton
        case .subagent:
            question("Why does image optimization rerun on every deploy?")
            AISubagent("research", status: replaying ? .running : .completed, result: replaying ? nil : "The cache is keyed on the commit SHA, so every deploy misses it and optimizes all 1,240 images again.", defaultOpen: true) {
                AITrace {
                    AITool("grep -rn cacheKey scripts", status: replaying ? .running : .completed, output: replaying ? nil : "scripts/optimize-images.ts:14: cacheKey = commit.sha", icon: replaying ? .loaderCircle : .circleCheck)
                    if !replaying {
                        AITool("sed -n 13,15p scripts/optimize-images.ts", output: "const cacheKey = commit.sha", icon: .circleCheck)
                        AITool("ls public/images | wc -l", output: "1240", icon: .circleCheck)
                    }
                }
            }
            if !replaying { answer("Image optimization reruns because its cache is keyed on the commit SHA, which changes on every deploy. Key the cache on a hash of public/images instead, and unchanged images will be skipped.") }
            replayButton
        case .suggestion:
            transcript
            VStack(alignment: .leading, spacing: density == .comfortable ? 0 : 8) {
                AISuggestions(["Add a dark mode toggle", "Fix the failing build", "Write tests for the form", "Upgrade to Next.js 16", "Add a loading state", "Find unused dependencies"]) { prompt in
                    send(.init(text: prompt, attachments: attachments, modelID: model, effort: effort))
                }.disabled(streaming)
                composer
            }
        case .task:
            question("Add Open Graph metadata to the home page.")
            AITrace {
                AITask("Found the project files", steps: [.init(id: "find", title: "Searched for app/page.tsx", icon: .search), .init(id: "read", title: "Read app/page.tsx", icon: .fileText, content: .code("export default function Page() {\n  return <Chat />\n}", language: "tsx"))], status: replaying ? .running : .completed, runningTitle: "Finding the project files")
                AITask("Updated the page metadata", steps: [.init(id: "layout", title: "Edited app/layout.tsx", icon: .fileText), .init(id: "page", title: "Edited app/page.tsx", icon: .fileText)])
            }
            if !replaying { answer("Added Open Graph defaults to app/layout.tsx and a title, description and image for the home page in app/page.tsx.") }
            replayButton
        case .terminal:
            question("Run the checks, then build the app.")
            AITrace {
                AITerminal(command: "pnpm lint", output: "No lint errors.", exitCode: 0)
                AITerminal(command: "pnpm test", output: "All tests passed.", exitCode: 0)
                AITerminal(command: "pnpm build", output: "> acme-chat@0.1.0 build\n> next build\n\n   ▲ Next.js 16.3.0\n   Creating an optimized production build ...\n ✓ Compiled successfully in 4.2s\n ✓ Generating static pages (12/12)\n\nRoute (app)                Size  First Load JS\n┌ ○ /                     1.9 kB       112 kB\n└ ƒ /api/chat              141 B       102 kB", status: replaying ? .running : .completed, exitCode: replaying ? nil : 0, defaultOpen: true)
            }
            if !replaying { answer("Lint and tests pass, and the build compiled both routes.") }
            replayButton
        case .testResults:
            question("Run the checkout tests.")
            AITestResults(suites: replaying ? [] : [
                .init(id: "cart", name: "cart.test.ts", tests: [.init(id: "a", name: "adds an item", status: .passed), .init(id: "b", name: "removes an item", status: .passed), .init(id: "c", name: "calculates the total", status: .passed)]),
                .init(id: "payment", name: "payment.test.ts", tests: [.init(id: "d", name: "charges the saved card", status: .passed), .init(id: "e", name: "retries a declined card", status: .failed, error: "Expected 2 charge attempts, received 1\n\n  at Object.<anonymous> (src/payment.test.ts:58:22)")])
            ], isRunning: replaying, command: "pnpm test checkout")
            if !replaying { answer("One test failed. The payment client does not retry a declined card, so the second charge attempt never happens.") }
            replayButton
        case .tool:
            question("Which package managers are installed?")
            AITrace {
                AITool("node --version", status: replaying ? .running : .completed, output: replaying ? nil : "v24.0.0")
                AITool("npm --version", output: "11.0.0")
                AITool("pnpm --version", status: .failed, output: "command not found: pnpm", defaultOpen: true)
            }
            answer("Node 24 and npm 11 are installed. pnpm is not.")
            replayButton
        }
    }
    private var replayButton: some View {
        Button {
            replaying = true
            responseTask?.cancel()
            responseTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(1600)) } catch { return }
                replaying = false
            }
        } label: { AITextLabel(replaying ? "Running…" : "Replay", weight: .medium) }.buttonStyle(AIButtonStyle(.outline, compact: true)).disabled(replaying)
    }
    private var composer: some View {
        AIPromptInput(text: $text, attachments: pattern == .promptInput ? nil : $attachments, models: [.chat, .suggestion].contains(pattern) ? [] : models, modelID: $model, effort: $effort,
                      status: streaming ? .streaming : .ready, placeholder: pattern == .chat ? "Ask the agent..." : "Ask the agent to change your code...",
                      sendButtonColor: pattern == .chat ? chatSendColor : nil, attachmentResetID: submissionRevision, compact: pattern == .chat,
                      onAttachmentError: { notice = $0.localizedDescription }, onStop: { responseTask?.cancel(); streaming = false }) { submission in
            if [.chat, .checkpoint, .suggestion].contains(pattern) { send(submission) }
            else { notice = "Submitted: \(submission.text.isEmpty ? "\(submission.attachments.count) attachment(s)" : submission.text)"; text = ""; attachments = []; submissionRevision += 1 }
        }
    }
    private func question(_ text: String) -> some View { AIMessage(role: .user) { AIMessageText(text) } }
    private func answer(_ text: String) -> some View { AIMessage(role: .assistant) { AIMessageResponse(text) } }
    @ViewBuilder private var transcript: some View {
        ForEach(messages) { message in
            AIMessage(role: message.role) {
                if !message.text.isEmpty {
                    if message.role == .user { AIMessageText(message.text) } else { AIMessageResponse(message.text) }
                }
                ForEach(Array(message.parts.enumerated()), id: \.offset) { _, part in
                    if case .attachment(let attachment) = part { AIAttachmentView(attachment) }
                }
            }
        }
    }
    private func send(_ submission: AIPromptSubmission) {
        guard !streaming, submission.canSend else { return }
        if pattern == .suggestion { messages.removeAll() }
        messages.append(.init(role: .user, text: submission.text, parts: submission.attachments.map(AIMessagePart.attachment)))
        text = ""; attachments = []; streaming = true
        let id = UUID().uuidString
        messages.append(.init(id: id, role: .assistant, text: ""))
        streamReply(to: submission.text, id: id)
    }
    private func streamReply(to prompt: String, id: String? = nil) {
        let id = id ?? UUID().uuidString
        if !messages.contains(where: { $0.id == id }) { messages.append(.init(id: id, role: .assistant)) }
        responseTask?.cancel()
        let reply: String
        switch pattern {
        case .suggestion: reply = Self.suggestionReplies[prompt] ?? "This demo only knows the suggestions. Pick one."
        case .checkpoint where prompt == "Update the docs to match.": reply = "Updated the Button page to say Action."
        case .chat where prompt == Self.chatPrompts[0]: reply = "Added a dark mode toggle to the settings page."
        case .chat where prompt == Self.chatPrompts[1]: reply = "The theme now follows the system setting by default."
        case .chat where prompt == Self.chatPrompts[2]: reply = "The demo build completed successfully."
        default: reply = "This is a local streaming demonstration. Connect your own async sequence or model provider to update the message text as tokens arrive."
        }
        streaming = true
        responseTask = Task { @MainActor in
            for word in reply.split(separator: " ") {
                do { try await Task.sleep(for: .milliseconds(65)) } catch { return }
                guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
                messages[index].text += (messages[index].text.isEmpty ? "" : " ") + word
            }
            streaming = false
            if pattern == .chat, text.isEmpty, let index = Self.chatPrompts.firstIndex(of: prompt),
               Self.chatPrompts.indices.contains(index + 1) { text = Self.chatPrompts[index + 1] }
        }
    }
}

#if os(macOS)
@MainActor enum SnapshotExporter {
    static func export() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".impeccable/review")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let captures = Pattern.allCases.map { ($0.rawValue, AnyView(DemoView(pattern: $0))) } + ValidationFixtures.cases
        for (captureName, captureView) in captures {
            for scheme in [ColorScheme.light, .dark] {
                for width in [CGFloat(640), 350] {
                    let theme = scheme == .dark ? AITheme.dark : .light
                    let content = captureView.padding(32).frame(width: width, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true).background(theme.background).environment(\.colorScheme, scheme).aiTheme(theme).aiAnimationsEnabled(false)
                    let host = NSHostingView(rootView: content)
                    let size = host.fittingSize
                    host.frame = NSRect(origin: .zero, size: size)
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
                    window.contentView = host
                    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                    host.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))
                    let settledSize = host.fittingSize
                    window.setContentSize(settledSize)
                    host.frame = NSRect(origin: .zero, size: settledSize)
                    host.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                        host.cacheDisplay(in: host.bounds, to: bitmap)
                        let name = "\(captureName)-\(scheme == .dark ? "dark" : "light")-\(Int(width)).png"
                        try? bitmap.representation(using: .png, properties: [:])?.write(to: root.appendingPathComponent(name))
                    }
                    window.contentView = nil

                }
            }
        }
        print("Exported component snapshots to \(root.path)")
    }
}
#endif
