import SwiftUI

public struct AICheckpoint: View {
    public var label: String
    public var restoreLabel: String
    public var isEnabled: Bool
    public var onRestore: () -> Void
    @Theme private var theme
    public init(_ label: String, restoreLabel: String = "Restore", isEnabled: Bool = true, onRestore: @escaping () -> Void) {
        self.label = label; self.restoreLabel = restoreLabel; self.isEnabled = isEnabled; self.onRestore = onRestore
    }
    public var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(theme.border).frame(height: 1)
            AITextLabel(label, color: theme.mutedForeground).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            if isEnabled { Button(action: onRestore) { AITextLabel(restoreLabel, size: 12, weight: .medium, color: theme.mutedForeground) }.buttonStyle(AIButtonStyle(.outline, size: .tiny)).fixedSize() }
            Rectangle().fill(theme.border).frame(height: 1)
        }.accessibilityElement(children: .contain)
    }
}
public enum AIConfirmationDecision: String, Sendable { case pending, approved, denied }
public struct AIConfirmation: View {
    public var title: String
    public var description: String?
    @Binding public var decision: AIConfirmationDecision
    public var onDecision: (AIConfirmationDecision) -> Void
    public var executionStatus: AIStatus
    public var output: String?
    public var toolName: String?
    public var submitDecision: ((AIConfirmationDecision) async throws -> Void)?
    @ScaledMetric(relativeTo: .body) private var minimumInfoWidth: CGFloat = 136
    @State private var submitting: AIConfirmationDecision?
    @State private var errorMessage: String?
    @State private var submissionTask: Task<Void, Never>?
    @Theme private var theme
    public init(_ title: String, description: String? = nil, decision: Binding<AIConfirmationDecision>, executionStatus: AIStatus = .running, output: String? = nil, toolName: String? = nil, submitDecision: ((AIConfirmationDecision) async throws -> Void)? = nil, onDecision: @escaping (AIConfirmationDecision) -> Void = { _ in }) {
        self.title = title; self.description = description; self._decision = decision; self.onDecision = onDecision; self.executionStatus = executionStatus; self.output = output; self.toolName = toolName; self.submitDecision = submitDecision
    }
    public var body: some View {
        Group {
        if decision == .pending {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { info.frame(idealWidth: minimumInfoWidth); actions }
                VStack(alignment: .leading, spacing: 12) { info; HStack { Spacer(); actions } }
            }.padding(.horizontal, 15).padding(.vertical, 13).foregroundStyle(theme.foreground)
                .background(RoundedRectangle(cornerRadius: theme.radius).strokeBorder(theme.border, lineWidth: 1))
            if let errorMessage { Text(errorMessage).aiFont(12).foregroundStyle(theme.destructive) }
        } else {
            AITool(toolName ?? title.replacingOccurrences(of: #"^Run "#, with: "", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "?")), status: decision == .denied ? .denied : executionStatus, output: output)
        }
        }.onDisappear { submissionTask?.cancel() }
    }
    private var info: some View {
        HStack(alignment: .top, spacing: 14) {
            AIIcon(.terminal).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                AITextLabel(title, weight: .medium).fixedSize(horizontal: false, vertical: true).frame(minHeight: 19.25)
                if let description { NativeTextParagraph(markdown: description).environment(\.aiParagraphMuted, true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var actions: some View {
        HStack(spacing: 8) {
            Button { decide(.denied) } label: { AITextLabel(submitting == .denied ? "Submitting…" : "Deny", weight: .medium) }.buttonStyle(AIButtonStyle(.outline, compact: true))
            Button { decide(.approved) } label: { AITextLabel(submitting == .approved ? "Submitting…" : "Approve", weight: .medium) }.buttonStyle(AIButtonStyle(.primary, compact: true))
        }.fixedSize().disabled(submitting != nil)
    }
    private func decide(_ value: AIConfirmationDecision) {
        guard decision == .pending, submitting == nil else { return }
        errorMessage = nil
        guard let submitDecision else { decision = value; onDecision(value); return }
        submitting = value
        submissionTask = Task { @MainActor in
            do { try await submitDecision(value); guard !Task.isCancelled else { submitting = nil; return }; decision = value; onDecision(value) }
            catch { errorMessage = error.localizedDescription }
            submitting = nil
        }
    }
}
public struct AIContext: View {
    public var usage: AIContextUsage
    @State private var showing = false
    @Theme private var theme
    public init(_ usage: AIContextUsage) { self.usage = usage }
    public var body: some View {
        Button { showing = true } label: { AITextLabel("\(usage.percent)% context", weight: .medium) }.buttonStyle(AIButtonStyle(.outline, compact: true))
            .modifier(AIHoverPreview(showing: $showing) { detail.padding(16).frame(width: 256).presentationCompactAdaptation(.popover) })
            .accessibilityLabel("Context used: \(usage.percent) percent. Show details")
    }
    public var detail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Context").fontWeight(.medium); Spacer(); Text("\(AIContextUsage.format(usage.used)) / \(AIContextUsage.format(Double(usage.limit)))").foregroundStyle(theme.mutedForeground) }
            GeometryReader { geo in
                Capsule().fill(theme.muted).overlay(alignment: .leading) {
                    Capsule().fill(theme.foreground).frame(width: geo.size.width * usage.fraction)
                }
            }.frame(height: 6).accessibilityLabel("Context used").accessibilityValue("\(usage.percent) percent")
            VStack(spacing: 4) {
                row("Input", usage.input); row("Output", usage.output); row("Reasoning", usage.reasoning)
            }
        }.aiFont().foregroundStyle(theme.foreground)
    }
    private func row(_ label: String, _ value: Int) -> some View {
        HStack { Text(label).foregroundStyle(theme.mutedForeground); Spacer(); Text(AIContextUsage.format(Double(value))) }
    }
}
public struct AIInlineCitation: View {
    public var sources: [AISource]
    @State private var showing = false
    @State private var index = 0
    @Theme private var theme
    public init(_ source: AISource) { sources = [source] }
    public init(sources: [AISource]) { self.sources = AISource.unique(sources) }
    public var body: some View {
        Button(sources.first?.hostname ?? "No sources") { showing = true }.buttonStyle(AIButtonStyle(.secondary, size: .tiny))
            .disabled(sources.isEmpty).modifier(AIHoverPreview(showing: $showing) {
                if !sources.isEmpty {
                    let source = sources[min(index, sources.count - 1)]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(source.title).aiFont(14, weight: .medium)
                        if let summary = source.summary { Text(summary).aiFont().foregroundStyle(theme.mutedForeground) }
                        Link(destination: source.url) { HStack { Text(source.hostname); AIIcon(.arrowUpRight, size: 12) }.aiHitTarget() }.aiFont(12)
                        if sources.count > 1 {
                            HStack {
                                Button { index = max(0, index - 1) } label: { AIIcon(.chevronRight).rotationEffect(.degrees(180)) }.disabled(index == 0).accessibilityLabel("Previous source")
                                Spacer(); Text("\(index + 1) / \(sources.count)").aiFont(12); Spacer()
                                Button { index = min(sources.count - 1, index + 1) } label: { AIIcon(.chevronRight) }.disabled(index >= sources.count - 1).accessibilityLabel("Next source")
                            }.buttonStyle(AIButtonStyle(.ghost, compact: true))
                        }
                    }.padding(16).frame(width: 256).foregroundStyle(theme.foreground).presentationCompactAdaptation(.popover)
                }
            })
            .onChange(of: sources) { _, _ in index = 0 }
    }
}
public struct AISources: View {
    public var sources: [AISource]
    public var defaultOpen: Bool
    public var showsEmptyState: Bool
    public init(_ sources: [AISource], defaultOpen: Bool = false, showsEmptyState: Bool = false) {
        self.sources = AISource.unique(sources); self.defaultOpen = defaultOpen; self.showsEmptyState = showsEmptyState
    }
    public var body: some View {
        if !sources.isEmpty || showsEmptyState { disclosure }
    }
    private var disclosure: some View {
        AITraceDisclosure("Used \(sources.count) sources", icon: .globe, defaultOpen: defaultOpen) {
            AITrace {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    Link(destination: source.url) {
                        HStack(spacing: 4) { AITraceLine(source.title.isEmpty ? source.hostname : source.title, icon: nil); AIIcon(.arrowUpRight, size: 14) }
                            .modifier(AIListRowTarget(index: index + 1, count: sources.count + 1))
                    }.buttonStyle(.plain).accessibilityHint("Opens in your browser")
                }
                if sources.isEmpty { Text("No sources.").aiFont() }
            }
        }.aligningTrigger(inRow: 0, of: sources.count + 1)
    }
}
public struct AISuggestion: View {
    public var text: String
    public var action: (String) -> Void
    public init(_ text: String, action: @escaping (String) -> Void) { self.text = text; self.action = action }
    public var body: some View { Button { action(text) } label: { AITextLabel(text, weight: .medium) }.buttonStyle(AIButtonStyle(.outline, compact: true)).fixedSize() }
}
public struct AISuggestions: View {
    public var suggestions: [String]
    public var onSelect: (String) -> Void
    public init(_ suggestions: [String], onSelect: @escaping (String) -> Void) { self.suggestions = suggestions; self.onSelect = onSelect }
    public var body: some View {
        AIHorizontalScroll {
            HStack(spacing: 8) { ForEach(Array(suggestions.enumerated()), id: \.offset) { _, text in AISuggestion(text, action: onSelect) } }
        }
    }
}
public struct AIFileTree: View {
    public var nodes: [AIFileNode]
    private var externalSelection: Binding<String?>?
    private var externalExpansion: Binding<Set<String>>?
    public var onSelect: (AIFileNode) -> Void
    @State private var localSelection: String?
    @State private var localExpansion: Set<String>
    @State private var focused: String?
    public init(_ nodes: [AIFileNode], selection: Binding<String?>? = nil, expandedPaths: Binding<Set<String>>? = nil, onSelect: @escaping (AIFileNode) -> Void = { _ in }) {
        self.nodes = nodes; self.externalSelection = selection; self.externalExpansion = expandedPaths; self.onSelect = onSelect
        self._localExpansion = State(initialValue: Set(Self.folders(nodes)))
    }
    private var selection: Binding<String?> { externalSelection ?? $localSelection }
    private var expanded: Binding<Set<String>> { externalExpansion ?? $localExpansion }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let rows = visibleNodes()
            ForEach(Array(rows.enumerated()), id: \.element.node.id) { index, row in
                FileTreeRow(node: row.node, depth: row.depth, index: index, count: rows.count, selection: selection, expanded: expanded, focus: $focused, onSelect: onSelect, onKey: handleKey)
            }
            if nodes.isEmpty { Text("No files.").aiFont().foregroundStyle(.secondary).padding(8) }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: nodes) { old, new in
                let newFolders = Set(Self.folders(new)).subtracting(Self.folders(old))
                if externalExpansion == nil { expanded.wrappedValue.formUnion(newFolders) }
            }
    }
    private func handleKey(_ key: KeyEquivalent) -> KeyPress.Result {
                let rows = visibleNodes()
                guard let index = rows.firstIndex(where: { $0.node.id == focused }) else { return .ignored }
                let node = rows[index].node
                switch key {
                case .return, .space:
                    if node.children != nil { if expanded.wrappedValue.contains(node.path) { expanded.wrappedValue.remove(node.path) } else { expanded.wrappedValue.insert(node.path) } }
                    else { selection.wrappedValue = node.path; onSelect(node) }
                case .upArrow: focused = rows[max(0, index - 1)].node.id
                case .downArrow: focused = rows[min(rows.count - 1, index + 1)].node.id
                case .rightArrow:
                    if node.children != nil { if expanded.wrappedValue.contains(node.path) { if let child = node.children?.first { focused = child.id } } else { expanded.wrappedValue.insert(node.path) } }
                case .leftArrow:
                    if expanded.wrappedValue.contains(node.path) { expanded.wrappedValue.remove(node.path) }
                    else if let parent = rows[index].parent { focused = parent }
                default: return .ignored
                }
                return .handled
    }
    private static func folders(_ nodes: [AIFileNode]) -> [String] { nodes.flatMap { node in node.children.map { [node.path] + folders($0) } ?? [] } }
    private func visibleNodes() -> [VisibleFile] {
        func walk(_ nodes: [AIFileNode], depth: Int, parent: String?) -> [VisibleFile] {
            nodes.flatMap { node in
                [VisibleFile(node: node, depth: depth, parent: parent)] + (node.children != nil && expanded.wrappedValue.contains(node.path) ? walk(node.children!, depth: depth + 1, parent: node.path) : [])
            }
        }
        return walk(nodes, depth: 0, parent: nil)
    }
}
private struct VisibleFile { var node: AIFileNode; var depth: Int; var parent: String? }
private struct FileTreeRow: View {
    var node: AIFileNode
    var depth: Int
    var index: Int
    var count: Int
    @Binding var selection: String?
    @Binding var expanded: Set<String>
    @Binding var focus: String?
    var onSelect: (AIFileNode) -> Void
    var onKey: (KeyEquivalent) -> KeyPress.Result
    @Theme private var theme
    @State private var hovered = false
    private var open: Bool { expanded.contains(node.path) }
    @FocusState private var rowFocused: Bool
    private func activate() {
        focus = node.id
        if node.children != nil { if open { expanded.remove(node.path) } else { expanded.insert(node.path) } }
        else { selection = node.path; onSelect(node) }
    }
    private var label: some View {
        HStack(spacing: 4) {
            if node.children != nil { AIIcon(.chevronRight).rotationEffect(.degrees(open ? 90 : 0)) }
            AIIcon(node.children != nil ? .folder : .file)
            AITextLabel(node.name, lineLimit: 1)
            Spacer(minLength: 0)
        }.aiFont().padding(.leading, 13).padding(.trailing, 13).frame(minHeight: 28)
            .foregroundStyle(theme.foreground)
            .background { Capsule().inset(by: 1).fill(selection == node.path ? theme.accent : hovered ? theme.muted : .clear) }
            .padding(.leading, CGFloat(depth) * 16)
            .modifier(AIListRowTarget(index: index, count: count))
    }
    var body: some View {
        Group {
            #if os(macOS)
            label.accessibilityHidden(true).overlay {
                NativeFileTreeButton(id: node.id, name: node.name,
                    value: node.children != nil ? (open ? "Expanded folder" : "Collapsed folder") : (selection == node.path ? "Selected" : "File"),
                    focus: $focus, activate: activate, onKey: onKey)
            }
            #else
            Button(action: activate) { label }.buttonStyle(.plain).focusable().focused($rowFocused)
                .onChange(of: focus) { _, value in rowFocused = value == node.id }
                .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return, .space]) { onKey($0.key) }
                .accessibilityLabel(node.name).accessibilityAddTraits(selection == node.path ? .isSelected : [])
                .accessibilityValue(node.children != nil ? (open ? "Expanded folder" : "Collapsed folder") : (selection == node.path ? "Selected" : "File"))
            #endif
        }.onHover { hovered = $0 }
    }
}
#if os(macOS)
import AppKit
private struct NativeFileTreeButton: NSViewRepresentable {
    var id: String
    var name: String
    var value: String
    @Binding var focus: String?
    var activate: () -> Void
    var onKey: (KeyEquivalent) -> KeyPress.Result
    func makeNSView(context: Context) -> FileKeyButton {
        let button = FileKeyButton(); button.title = ""; button.isTransparent = true; button.isBordered = false
        button.target = button; button.action = #selector(FileKeyButton.choose)
        return button
    }
    func updateNSView(_ button: FileKeyButton, context: Context) {
        button.setAccessibilityLabel(name); button.setAccessibilityValue(value)
        button.activate = activate; button.onKey = onKey
        if button.lastFocus != focus {
            button.lastFocus = focus
            if focus == id { button.window?.makeFirstResponder(button) }
        }
    }
}
private final class FileKeyButton: NSButton {
    var lastFocus: String?
    var activate: () -> Void = {}
    var onKey: (KeyEquivalent) -> KeyPress.Result = { _ in .ignored }
    override var acceptsFirstResponder: Bool { true }
    @objc func choose() { window?.makeFirstResponder(self); activate() }
    override func keyDown(with event: NSEvent) {
        let key: KeyEquivalent?
        switch event.keyCode {
        case 123: key = .leftArrow
        case 124: key = .rightArrow
        case 125: key = .downArrow
        case 126: key = .upArrow
        case 36, 76: key = .return
        case 49: key = .space
        default: key = nil
        }
        if let key, onKey(key) == .handled { return }
        super.keyDown(with: event)
    }
}
#endif
