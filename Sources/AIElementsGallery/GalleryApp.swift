import SwiftUI
import AIElements
#if os(macOS)
import AppKit
#endif

@main
struct GalleryApp: App {
    init() {
        #if os(macOS)
        if CommandLine.arguments.contains("--foundation-snapshots") {
            MainActor.assumeIsolated { FoundationAuditExporter.export() }; exit(0)
        }
        if CommandLine.arguments.contains("--ui-snapshots") {
            MainActor.assumeIsolated { UIFixtureExporter.export() }
            exit(0)
        }
        if CommandLine.arguments.contains("--snapshots") {
            MainActor.assumeIsolated { SnapshotExporter.export() }
            exit(0)
        }
        #endif
    }
    var body: some Scene {
        WindowGroup("AI Elements · Swift") {
            if CommandLine.arguments.contains("--foundation-snapshots") {
                Text("Capturing foundation fixtures")
                    #if os(iOS)
                    .task { await FoundationAuditExporter.export() }
                    #endif
            } else if let index = CommandLine.arguments.firstIndex(of: "--foundation-preview"), CommandLine.arguments.indices.contains(index + 1) {
                ScrollView { FoundationAuditView(name: CommandLine.arguments[index + 1]).padding(.vertical, 20) }
                    .frame(maxWidth: .infinity).preferredColorScheme(CommandLine.arguments.contains("--dark") ? .dark : .light)
            } else if let index = CommandLine.arguments.firstIndex(of: "--ui-preview"), CommandLine.arguments.indices.contains(index + 1) {
                ScrollView { UIFixtureView(name: CommandLine.arguments[index + 1]).frame(width: 360).padding(.vertical, 20) }
                    .frame(maxWidth: .infinity).background(CommandLine.arguments.contains("--dark") ? AITheme.dark.background : .white)
                    .preferredColorScheme(CommandLine.arguments.contains("--dark") ? .dark : .light)
            } else { GalleryView() }
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 820)
        #endif
    }
}

struct GalleryView: View {
    @State private var selection: Pattern? = .tool
    @State private var query = ""
    @State private var dark = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("AI Elements") {
                    ForEach(Pattern.allCases.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { pattern in
                        NavigationLink(value: pattern) { Text(pattern.title).font(AITypography.font()) }
                    }
                }
            }.searchable(text: $query, prompt: "Find a component")
                .navigationTitle("AI Elements")
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 280)
        } detail: {
            if let selection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selection.title).font(AITypography.font(30, weight: .semibold))
                            Text(selection.subtitle).font(AITypography.font(15)).foregroundStyle(.secondary)
                        }
                        let metadataLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 20))
                        metadataLayout {
                            Text("Preview").font(AITypography.font(14, weight: .medium))
                            Text("SwiftUI").font(AITypography.font()).foregroundStyle(.secondary)
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            AIBadge("iOS + macOS")
                        }
                        DemoView(pattern: selection).id(selection)
                            .padding(32).frame(maxWidth: .infinity, minHeight: 280)
                            .background(RoundedRectangle(cornerRadius: 18).strokeBorder(dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Usage").font(AITypography.font(20, weight: .semibold))
                            AICodeBlock(selection.example, language: "Swift", showCopy: true)
                            Text("Interactive preview uses local demonstration data. No model calls or commands are executed.").font(AITypography.font(12)).foregroundStyle(.secondary)
                        }
                        Link("View original component ↗", destination: selection.url).font(AITypography.font(13))
                    }.padding(32).frame(maxWidth: 800).frame(maxWidth: .infinity, alignment: .top)
                }.background(dark ? AITheme.dark.background : AITheme.light.background).navigationTitle(selection.title)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar { Button { dark.toggle() } label: { AIIcon(dark ? .sun : .moon) }.accessibilityLabel("Toggle appearance") }
            } else { Text("Select a component").font(AITypography.font(20)) }
        }.preferredColorScheme(dark ? .dark : .light)
            .tint(dark ? .white : .black)
            .onAppear {
                if let index = CommandLine.arguments.firstIndex(of: "--pattern"), CommandLine.arguments.indices.contains(index + 1) {
                    selection = Pattern(rawValue: CommandLine.arguments[index + 1]) ?? .tool
                }
                if CommandLine.arguments.contains("--dark") { dark = true }
            }
    }
}

enum Pattern: String, CaseIterable, Identifiable {
    case chainOfThought = "chain-of-thought", chat, checkpoint, confirmation, context, fileTree = "file-tree"
    case inlineCitation = "inline-citation", message, modelSelector = "model-selector", plan, promptInput = "prompt-input"
    case queue, reasoning, sources, stackTrace = "stack-trace", subagent, suggestion, task, terminal, testResults = "test-results", tool
    case generativeUI = "generative-ui", barChart = "bar-chart", lineChart = "line-chart", areaChart = "area-chart"
    var id: String { rawValue }
    var title: String { self == .generativeUI ? "Generative UI" : rawValue.split(separator: "-").map { $0.capitalized }.joined(separator: " ") }
    var url: URL { URL(string: [.generativeUI, .barChart, .lineChart, .areaChart].contains(self) ? "https://ui.shadcn.com/docs/components/chart" : "https://ui.shadcn.com/docs/ai-elements/base/\(rawValue)")! }
    var subtitle: String {
        switch self {
        case .generativeUI: "An interface that arrives progressively: controls first, chart data next."
        case .barChart, .lineChart, .areaChart: "Native charts using shadcn/ui card geometry and chart tokens."
        case .chainOfThought: "A summary that expands into the steps an agent took."
        case .chat: "A conversation that keeps your place while the reply streams."
        case .checkpoint: "A point in the conversation you can return to."
        case .confirmation: "Approve or deny a tool before it runs."
        case .context: "How much of the context window the conversation has used."
        case .fileTree: "The files the agent changed, as a folder tree."
        case .inlineCitation: "A source in the sentence, with a preview and link."
        case .message: "One turn. The person's message and the agent's reply."
        case .modelSelector: "Choose the model and how hard it thinks."
        case .plan: "The steps the agent plans to take, and how far it has got."
        case .promptInput: "A message field with attachments and a send button."
        case .queue: "The agent's todo list, split into what is left and what is done."
        case .reasoning: "The agent's thinking as it streams."
        case .sources: "The links the agent used for a reply."
        case .stackTrace: "A failed tool call and its stack frames."
        case .subagent: "A subagent run, with its tool calls and result."
        case .suggestion: "A short prompt you can send to the agent in one click."
        case .task: "The steps the agent takes, as it takes them."
        case .terminal: "A command the agent runs, with its output."
        case .testResults: "A test run by the agent, with its suites and failures."
        case .tool: "A tool call the agent makes, from input to output."
        }
    }
    var example: String {
        switch self {
        case .generativeUI: "AIUIRenderer(store: store) { event in\n    handle(event)\n}\n// Feed each network chunk into try store.receive(bytes)"
        case .barChart, .lineChart, .areaChart: "AIChart(.bar, data: rows, series: series)\n    .aspectRatio(16 / 9, contentMode: .fit)"
        case .chainOfThought: "AIChainOfThought(steps: steps, defaultOpen: true)"
        case .chat: "AIChat(messages: messages, isStreaming: isStreaming)"
        case .checkpoint: "AICheckpoint(\"Checkpoint saved\") {\n    restoreConversation()\n}"
        case .confirmation: "AIConfirmation(\"Run pnpm install?\",\n    decision: $decision\n) { decision in\n    handleApproval(decision)\n}"
        case .context: "AIContext(.init(input: 8420, output: 1260,\n    reasoning: 980, limit: 128000))"
        case .fileTree: "AIFileTree(nodes, selection: $selectedPath) { file in\n    openFile(file.path)\n}"
        case .inlineCitation: "AIInlineCitation(.init(title: \"Documentation\",\n    url: URL(string: \"https://ui.shadcn.com\")!))"
        case .message: "AIMessage(role: .assistant) {\n    AIMessageResponse(response)\n    AIMessageActions(text: response)\n}"
        case .modelSelector: "AIModelSelector(models: models,\n    selection: $modelID, effort: $effort)"
        case .plan: "AIPlan(\"Migrate to Base UI\", steps: steps)"
        case .promptInput: "AIPromptInput(text: $text, attachments: $files,\n    models: models, modelID: $modelID, effort: $effort\n) { submission in\n    send(submission)\n}"
        case .queue: "AIQueue(items: todos) { item in\n    selectTask(item.id)\n}"
        case .reasoning: "AIReasoning(reasoningText,\n    isStreaming: true, duration: 5)"
        case .sources: "AISources(sources, defaultOpen: true)"
        case .stackTrace: "AIStackTrace(stack, defaultOpen: true) { frame in\n    navigateToSource(frame)\n}"
        case .subagent: "AISubagent(\"research\", result: result) {\n    AITool(\"grep -rn cacheKey scripts\", output: output)\n}"
        case .suggestion: "AISuggestions([\"Explain this code\", \"Fix the bug\"]) {\n    sendPrompt($0)\n}"
        case .task: "AITask(\"Found the project files\", steps: steps)"
        case .terminal: "AITerminal(command: \"pnpm build\",\n    output: output, status: .completed)"
        case .testResults: "AITestResults(suites: suites)"
        case .tool: "AITrace {\n    AITool(\"node --version\", output: \"v24.0.0\")\n    AITool(\"pnpm --version\", status: .failed,\n        output: \"command not found: pnpm\", defaultOpen: true)\n}"
        }
    }
}
