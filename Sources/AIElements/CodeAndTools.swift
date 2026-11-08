import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

@MainActor enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
public struct AICopyButton: View {
    public var text: String
    @Theme private var theme
    @State private var copied = false
    public var iconSize: CGFloat
    public init(_ text: String, iconSize: CGFloat = 16) { self.text = text; self.iconSize = iconSize }
    public var body: some View {
        Button { Clipboard.copy(text); copied = true } label: { AIIcon(copied ? .check : .copy, size: iconSize).foregroundStyle(theme.mutedForeground) }
            .buttonStyle(AIButtonStyle(.ghost, size: .iconSmall)).accessibilityLabel(copied ? "Copied" : "Copy").help(copied ? "Copied" : "Copy")
            .task(id: copied) { if copied { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { copied = false } } }
    }
}
public enum AICodeLineStyle: Sendable { case normal, added, removed, highlighted }
public struct AICodeBlock: View {
    public var code: String
    public var language: String?
    public var showLineNumbers: Bool
    public var showsWrapControl: Bool
    public var showCopy: Bool
    public var maxHeight: CGFloat
    public var wrap: Bool
    public var lineStyles: [Int: AICodeLineStyle]
    public var highlightedCode: AttributedString?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.aiControlDensity) private var density
    @State private var wrapOverride: Bool?
    @Theme private var theme
    public init(_ code: String, language: String? = nil, showLineNumbers: Bool = false, showCopy: Bool = false, maxHeight: CGFloat = 256, wrap: Bool = false, lineStyles: [Int: AICodeLineStyle] = [:], highlightedCode: AttributedString? = nil, showsWrapControl: Bool = true) {
        self.showsWrapControl = showsWrapControl
        self.code = code; self.language = language; self.showLineNumbers = showLineNumbers; self.showCopy = showCopy; self.maxHeight = maxHeight; self.wrap = wrap; self.lineStyles = lineStyles; self.highlightedCode = highlightedCode
    }
    public var body: some View {
        let wrapping = wrapOverride ?? wrap
        VStack(alignment: .leading, spacing: 0) {
            if language != nil || showCopy {
                HStack {
                    Text(language ?? "").aiFont(14, weight: .medium).foregroundStyle(theme.foreground); Spacer()
                    if language != nil && showsWrapControl {
                        Button { wrapOverride = !wrapping } label: { AIIcon(.wrapText, size: 14) }
                            .buttonStyle(AIButtonStyle(.ghost, size: .iconSmall)).accessibilityLabel("Wrap lines").accessibilityValue(wrapping ? "On" : "Off").help("Toggle line wrapping")
                    }
                    if showCopy { AICopyButton(code, iconSize: 12) }
                }.foregroundStyle(theme.mutedForeground).padding(.horizontal, 16)
                    .frame(minHeight: density == .comfortable ? 44 : 36, alignment: .bottom)
                    .offset(y: 4)
            }
            ScrollView(wrapping ? [.vertical] : [.horizontal, .vertical]) {
                Group {
                    if showLineNumbers || !lineStyles.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(styledLines.enumerated()), id: \.offset) { index, line in
                                HStack(alignment: .top, spacing: 16) {
                                    if showLineNumbers { Text(String(index + 1)).foregroundStyle(theme.mutedForeground).frame(minWidth: 20, alignment: .trailing).accessibilityHidden(true) }
                                    Text(line.characters.isEmpty ? AttributedString(" ") : line).frame(maxWidth: wrapping ? .infinity : nil, alignment: .leading).textSelection(.enabled)
                                }.frame(minHeight: 22.75).frame(maxWidth: .infinity, alignment: .leading).background(lineColor(index + 1))
                            }
                        }
                    } else if wrapping && language == nil && highlightedCode == nil {
                        NativeTextParagraph(verbatimCode: code)
                    } else { Text(code.isEmpty ? AttributedString(" ") : displayCode).textSelection(.enabled) }
                }.aiFont(language == nil ? 12 : 14, mono: true).lineSpacing(4).foregroundStyle(theme.foreground)
                    .fixedSize(horizontal: !wrapping, vertical: true).frame(maxWidth: wrapping ? .infinity : nil, alignment: .leading).padding(.horizontal, language == nil ? 12 : 16)
                    .padding(.top, language == nil ? 12 : 8)
                    .padding(.bottom, language == nil ? 12 : 16)
            }.defaultScrollAnchor(.topLeading).frame(maxHeight: maxHeight).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).background(theme.muted, in: RoundedRectangle(cornerRadius: theme.radius))
    }
    private var displayCode: AttributedString {
        if let highlightedCode { return highlightedCode }
        var value = AttributedString(code)
        guard ["sh", "shell", "bash", "zsh"].contains(language?.lowercased() ?? "") else { return value }
        let dark = scheme == .dark
        value.foregroundColor = dark ? Color(red: 158 / 255, green: 203 / 255, blue: 1) : Color(red: 0.10, green: 0.24, blue: 0.38)
        for match in code.matches(of: Self.commandAtLineStart) {
            if let token = Range(match.output.1.startIndex..<match.output.1.endIndex, in: value) {
                value[token].foregroundColor = dark ? Color(red: 179 / 255, green: 146 / 255, blue: 240 / 255) : Color(red: 0.44, green: 0.25, blue: 0.64)
            }
        }
        return value
    }
    private static let commandAtLineStart = #/(?m)^[ \t]*([\w.\/-]+)/#

    var styledLines: [AttributedString] {
        let source = displayCode
        return source.characters.split(separator: "\n", omittingEmptySubsequences: false).map {
            AttributedString(source[$0.startIndex..<$0.endIndex])
        }
    }
    private func lineColor(_ line: Int) -> Color {
        switch lineStyles[line] ?? .normal { case .normal: .clear; case .added: .green.opacity(0.12); case .removed: theme.destructive.opacity(0.12); case .highlighted: theme.foreground.opacity(0.07) }
    }
}
public struct AITool: View {
    public var name: String
    public var status: AIStatus
    public var input: String?
    public var output: String?
    public var icon: AIIconName
    public var defaultOpen: Bool?
    public var isExpanded: Binding<Bool>?
    public var outputInSheet: Bool
    public var title: String?
    @State private var showingOutput = false
    public init(_ name: String, status: AIStatus = .completed, input: String? = nil, output: String? = nil, defaultOpen: Bool? = nil, isExpanded: Binding<Bool>? = nil, icon: AIIconName = .terminal, outputInSheet: Bool = false, title: String? = nil) {
        self.name = name; self.status = status; self.input = input; self.output = output; self.defaultOpen = defaultOpen; self.isExpanded = isExpanded; self.icon = icon; self.outputInSheet = outputInSheet; self.title = title
    }
    public var body: some View {
        let label = title ?? "\(status.verb) \(name)"
        Group {
            if output != nil && outputInSheet {
                Button { showingOutput = true } label: { AITraceLine(label, icon: icon, status: status).aiHitTarget() }.buttonStyle(.plain)
            } else if output != nil {
                AITraceDisclosure(label, icon: icon, status: status, defaultOpen: defaultOpen, isExpanded: isExpanded, autoExpand: status == .failed) { outputContent }
            } else { AITraceLine(label, icon: icon, status: status) }
        }.sheet(isPresented: $showingOutput) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text(label).aiFont(16, weight: .medium); Spacer(); Button("Done") { showingOutput = false }.buttonStyle(AIButtonStyle()) }
                ScrollView { outputContent }
            }.padding(24).frame(minWidth: 280, minHeight: 300)
        }
    }
    private var outputContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let input { AICodeBlock(input, language: "Input", wrap: true) }
            if let output { AICodeBlock(output, wrap: true) }
        }
    }
}
public struct AITerminal: View {
    public var command: String
    public var output: String
    public var status: AIStatus
    public var exitCode: Int?
    public var defaultOpen: Bool?
    public var isExpanded: Binding<Bool>?
    public init(command: String, output: String, status: AIStatus = .completed, exitCode: Int? = nil, defaultOpen: Bool? = nil, isExpanded: Binding<Bool>? = nil) {
        self.command = command; self.output = output; self.status = status; self.exitCode = exitCode; self.defaultOpen = defaultOpen; self.isExpanded = isExpanded
    }
    public var body: some View {
        let state: AIStatus = status == .running ? .running : exitCode.map { $0 == 0 ? .completed : .failed } ?? status
        let title = state == .failed && exitCode != nil ? "\(command) exited with code \(exitCode!)" : "\(state.verb) \(command)"
        if output.isEmpty { AITraceLine(title, icon: .terminal, status: state) }
        else {
            AITraceDisclosure(title, icon: .terminal, status: state, defaultOpen: defaultOpen, isExpanded: isExpanded, autoExpand: state == .running || state == .failed) {
                AITerminalOutput(output: output, streaming: state == .running)
            }
        }
    }
}
private struct AITerminalOutput: View {
    var output: String
    var streaming: Bool
    @Theme private var theme
    var body: some View {
        // Size the viewport from the same wrapped text used inside the scroll view.
        logText.padding(12).padding(.bottom, 1).hidden().accessibilityHidden(true)
            .frame(maxHeight: 256, alignment: .top).clipped()
            .overlay {
                AIConversation(revision: output, isStreaming: streaming, initialScrollToBottom: streaming, contentInset: 12) {
                    logText
                }
            }.background(theme.muted, in: RoundedRectangle(cornerRadius: theme.radius))
    }
    private var logText: some View {
        NativeTextParagraph(verbatimCode: output).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
public struct AIStackFrame: Identifiable, Equatable, Sendable {
    public var id: Int
    public var raw: String
    public var function: String?
    public var file: String?
    public var line: Int?
    public var column: Int?
    public var isFramework: Bool { raw.contains("node_modules") || raw.contains("node:internal") || raw.contains("/System/Library/") }
    public static func parse(_ stack: String) -> [AIStackFrame] {
        let pattern = #"(?:at\s+)?(?:(.*?)\s+\()?([^()]+?):(\d+)(?::(\d+))?\)?$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        return stack.components(separatedBy: "\n").dropFirst().enumerated().compactMap { index, raw in
            let text = raw.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            var frame = AIStackFrame(id: index, raw: raw)
            if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                func part(_ n: Int) -> String? { Range(match.range(at: n), in: text).map { String(text[$0]) } }
                frame.function = part(1); frame.file = part(2); frame.line = part(3).flatMap(Int.init); frame.column = part(4).flatMap(Int.init)
            }
            return frame
        }
    }
}
public struct AIStackTrace: View {
    public var stack: String
    public var defaultOpen: Bool
    public var onSelectFrame: ((String) -> Void)?
    public var onOpenFrame: ((AIStackFrame) -> Void)?
    @Theme private var theme
    public init(_ stack: String, defaultOpen: Bool = false, onOpenFrame: ((AIStackFrame) -> Void)? = nil, onSelectFrame: ((String) -> Void)? = nil) {
        self.stack = stack; self.defaultOpen = defaultOpen; self.onOpenFrame = onOpenFrame; self.onSelectFrame = onSelectFrame
    }
    public var body: some View {
        let error = stack.components(separatedBy: "\n").first ?? "Unknown error"
        let frames = AIStackFrame.parse(stack)
        AITraceDisclosure("Failed: \(error)", icon: .terminal, status: .failed, defaultOpen: defaultOpen) {
            AITrace {
                Text(error).aiFont(12, mono: true).foregroundStyle(theme.destructive).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                let appFrames = frames.filter { !$0.isFramework }
                let framework = frames.filter(\.isFramework)
                let interactiveFrames = onOpenFrame != nil || onSelectFrame != nil ? appFrames.count : 0
                let rowCount = interactiveFrames + (framework.isEmpty ? 0 : 1)
                ForEach(Array(appFrames.enumerated()), id: \.element.id) { index, frame in
                    frameView(frame, index: index, count: rowCount)
                }
                if !framework.isEmpty {
                    AITraceDisclosure("\(framework.count) framework frames", icon: .layers) {
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(framework) { frame in
                                    let line = Text(verbatim: frame.raw).aiFont(12, mono: true).fixedSize()
                                    if onOpenFrame != nil || onSelectFrame != nil {
                                        Button { onOpenFrame?(frame); onSelectFrame?(frame.raw) } label: { line.aiHitTarget() }.buttonStyle(.plain)
                                    } else { line.textSelection(.enabled) }
                                }
                            }.padding(12)
                        }.background(theme.muted, in: RoundedRectangle(cornerRadius: theme.radius))
                    }.aligningTrigger(inRow: interactiveFrames, of: rowCount)
                }
            }
        }
    }
    @ViewBuilder private func frameView(_ frame: AIStackFrame, index: Int, count: Int) -> some View {
        let title = frame.file.map { "\(frame.function.map { $0 + " in " } ?? "")\($0):\(frame.line ?? 0)" } ?? frame.raw
        if onOpenFrame != nil || onSelectFrame != nil {
            Button {
                onOpenFrame?(frame)
                onSelectFrame?(frame.raw)
            } label: {
                AITraceLine(title, icon: .fileCode)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(AIListRowTarget(index: index, count: count))
            }.buttonStyle(.plain).help(frame.raw)
        } else { AITraceLine(title, icon: .fileCode).help(frame.raw) }
    }
}
public struct AITestResults: View {
    public var suites: [AITestSuite]
    public var isRunning: Bool
    public var isExpanded: Binding<Bool>?
    public var command: String
    public var commandError: String?
    public init(suites: [AITestSuite], isRunning: Bool = false, command: String = "tests", commandError: String? = nil, isExpanded: Binding<Bool>? = nil) {
        self.suites = suites; self.isRunning = isRunning; self.command = command
        self.commandError = commandError; self.isExpanded = isExpanded
    }
    public var body: some View {
        if let commandError {
            AITraceDisclosure("Failed to run \(command)", icon: .flaskConical, status: .failed, isExpanded: isExpanded, autoExpand: true) {
                Text(verbatim: commandError).textSelection(.enabled)
            }
        } else if suites.isEmpty {
            AITraceLine(isRunning ? "Running \(command)" : "No tests ran.", icon: .flaskConical, status: isRunning ? .running : .completed)
        } else { results }
    }
    private var results: some View {
        let tests = suites.flatMap(\.tests)
        let failed = tests.filter { $0.status == .failed }.count
        return AITraceDisclosure("\(isRunning ? "Running" : "Ran") \(summary(tests))", icon: .flaskConical,
                          status: isRunning ? .running : failed > 0 ? .failed : .completed, isExpanded: isExpanded, autoExpand: isRunning || failed > 0) {
            AITrace {
                ForEach(suites) { suite in
                    AITraceDisclosure("\(suite.name), \(summary(suite.tests))", icon: .fileCode, status: suite.failedCount > 0 ? .failed : .completed, autoExpand: suite.failedCount > 0) {
                        AITrace {
                            ForEach(suite.tests) { test in
                                if test.status == .failed {
                                    AITraceDisclosure(test.name, icon: .x, status: .failed, defaultOpen: true) { AICodeBlock(test.error ?? "Test failed without an error message.", wrap: true) }
                                } else { AITraceLine(test.status == .skipped ? "Skipped \(test.name)" : test.name, icon: test.status == .skipped ? .circleDashed : .check) }
                            }
                        }
                    }
                }
            }
        }
    }
    static func counts(_ tests: [AITestCase]) -> String {
        let failed = tests.filter { $0.status == .failed }.count, skipped = tests.filter { $0.status == .skipped }.count
        return "\(tests.count) tests" + (failed > 0 ? ", \(failed) failed" : "") + (skipped > 0 ? ", \(skipped) skipped" : "")
    }
    private func summary(_ tests: [AITestCase]) -> String { Self.counts(tests) }
}
