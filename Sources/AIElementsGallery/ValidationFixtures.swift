import SwiftUI
import AIElements

/// Deterministic state fixtures for regression captures; not part of the public library.
@MainActor enum ValidationFixtures {
    static var cases: [(String, AnyView)] {
        let url = URL(string: "https://example.com/documentation")!
        let source = AISource(url: url)
        let steps: [AIStep] = [.init(id: "a", title: "Read project files", status: .completed, icon: .fileText), .init(id: "b", title: "Run the build", status: .running, icon: .terminal), .init(id: "c", title: "Check the result", status: .pending)]
        return [
            ("state-chain-running", AnyView(AIChainOfThought(steps: steps))),
            ("state-chain-failed", AnyView(AIChainOfThought(steps: [.init(id: "failed", title: "Failed to read the build log", detail: "The log is unavailable. Retry after the build finishes.", status: .failed)]))),
            ("state-task-failed", AnyView(AITask("Update page metadata", steps: [.init(id: "failed", title: "Failed to update app/page.tsx", status: .failed, content: .code("Permission denied", language: nil))]))),
            ("state-queue-details", AnyView(AIQueue(items: [.init(id: "active", title: "Checking contrast", status: .running, content: .markdown("Check **text** and focus states.")), .init(id: "pending", title: "Write regression tests", status: .pending), .init(id: "done", title: "Read the design tokens", status: .completed)]))),
            ("state-reasoning-empty", AnyView(AIReasoning("", isStreaming: true))),
            ("state-subagent-pending", AnyView(AISubagent("research", status: .pending) { EmptyView() })),
            ("state-subagent-denied", AnyView(AISubagent("research", status: .denied) { EmptyView() })),
            ("state-subagent-details", AnyView(AISubagent("research", task: "Inspect the image cache.", model: "Example model", tools: ["search", "read"], duration: 5.2, defaultOpen: true) { AITool("read cache.ts", output: "cacheKey = commit.sha", icon: .fileText) })),
            ("state-terminal-error", AnyView(AITerminal(command: "pnpm lint", output: "src/main.ts:12: unused variable", exitCode: 1))),
            ("state-terminal-empty", AnyView(AITerminal(command: "pnpm build", output: "", status: .running))),
            ("state-tool-input", AnyView(AITool("readFile", status: .running, input: "app/page.tsx"))),
            ("state-confirmation-denied", AnyView(AIConfirmation("Run pnpm install?", decision: .constant(.denied)))),
            ("state-confirmation-failed", AnyView(AIConfirmation("Run pnpm install?", decision: .constant(.approved), executionStatus: .failed, output: "The package registry is unavailable."))),
            ("state-tests-skipped", AnyView(AITestResults(suites: [.init(id: "test", name: "profile.test.ts", tests: [.init(id: "pass", name: "saves a profile", status: .passed), .init(id: "skip", name: "uploads an avatar", status: .skipped), .init(id: "fail", name: "rejects invalid input", status: .failed, error: "Expected 400, received 200")])]))),
            ("state-tests-waiting", AnyView(AITestResults(suites: [], isRunning: true))),
            ("state-prompt-submitted", AnyView(AIPromptInput(text: .constant("Review the current changes."), status: .submitted) { _ in })),
            ("state-prompt-error", AnyView(AIPromptInput(text: .constant("请保留这份草稿。"), attachments: .constant([.init(name: "very-long-file-name-for-layout-check.swift", byteCount: 1024)]), status: .failed) { _ in })),
            ("state-sources-deduped", AnyView(AISources([source, source, .init(title: "  ", url: URL(string: "https://swift.org")!)], defaultOpen: true))),
            ("state-markdown-rich", AnyView(AIMessageResponse("# Streaming reply\n\n- [x] Read the files\n- [ ] Run the tests\n  - Check the failed suite\n\n| Target | Result |\n| --- | --- |\n| iOS | Passed |\n| macOS | Passed |\n\n> Keep the user's place while text arrives.\n\n```swift\nlet message = AIChatMessage(role: .assistant, text: \"Hello\")\n```"))),
            ("state-chat-parts", AnyView(AIChat(messages: [.init(id: "q", role: .user, text: "Read the project files."), .init(id: "a", role: .assistant, parts: [.reasoning(text: "Inspect the project before making changes.", isStreaming: false, duration: 2), .tool(name: "read Package.swift", status: .completed, output: "// swift-tools-version: 5.9"), .text("The project supports **iOS and macOS**."), .sources([source])])]).frame(height: 420)))
        ]
    }
}
