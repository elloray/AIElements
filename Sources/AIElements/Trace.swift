import SwiftUI

/// The shared layout primitive behind agent activity. Reference gap: 8pt.
public struct AITrace<Content: View>: View {
    @Environment(\.aiControlDensity) private var density
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View { VStack(alignment: .leading, spacing: density == .comfortable ? 0 : 8) { content }.frame(maxWidth: .infinity, alignment: .leading) }
}
public struct AITraceLine: View {
    public var title: String
    public var icon: AIIconName?
    public var status: AIStatus
    public var detail: String?
    @Environment(\.aiControlDensity) private var density
    private var dimsPending: Bool
    @Theme private var theme
    public init(_ title: String, icon: AIIconName? = .circleCheck, status: AIStatus = .completed, detail: String? = nil, dimsPending: Bool = true) {
        self.dimsPending = dimsPending
        self.title = title; self.icon = icon; self.status = status; self.detail = detail
    }
    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if icon == .loaderCircle && status == .running { AISpinner() }
            else if let icon { AIIcon(icon) }
            AITextLabel(title, color: status == .failed ? theme.destructive : theme.mutedForeground, lineLimit: detail == nil ? 1 : nil).fixedSize(horizontal: false, vertical: true).modifier(AIShimmer(active: status == .running))
            if let detail { AITextLabel(detail, color: theme.mutedForeground.opacity(0.78)).fixedSize(horizontal: false, vertical: true).layoutPriority(1) }
        }.aiFont().frame(minHeight: density == .comfortable ? 28 : 20).foregroundStyle(status == .failed ? theme.destructive : theme.mutedForeground)
            .opacity(dimsPending && status == .pending ? 0.6 : 1)
            .accessibilityElement(children: .combine).accessibilityLabel(title).accessibilityValue(status.label)
    }
}
/// Controlled or internally managed disclosure; nested content retains its state when collapsed.
public struct AITraceDisclosure<Content: View>: View {
    public var title: String
    public var icon: AIIconName?
    public var status: AIStatus
    public var detail: String?
    private let content: Content
    private var controlled: Binding<Bool>?
    @Environment(\.aiControlDensity) private var density
    private var autoExpand: Bool
    @State private var localOpen: Bool?
    @Environment(\.aiAnimationsActive) private var parentAnimations
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Theme private var theme
    public init(_ title: String, icon: AIIconName? = .circleCheck, status: AIStatus = .completed,
                detail: String? = nil, defaultOpen: Bool? = nil, isExpanded: Binding<Bool>? = nil, autoExpand: Bool = false,
                @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.status = status; self.detail = detail
        self.controlled = isExpanded; self.autoExpand = autoExpand; self._localOpen = State(initialValue: defaultOpen); self.content = content()
    }
    private var triggerRow = AIListRowTarget(index: 0, count: 1)

    func aligningTrigger(inRow index: Int, of count: Int) -> Self {
        var disclosure = self
        disclosure.triggerRow = AIListRowTarget(index: index, count: count)
        return disclosure
    }
    private var open: Bool { controlled?.wrappedValue ?? localOpen ?? autoExpand }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    if let controlled { controlled.wrappedValue.toggle() } else { localOpen = !open }
                }
            } label: {
                HStack(spacing: 4) {
                    AITraceLine(title, icon: icon, status: status, detail: detail)
                    AIIcon(.chevronRight).rotationEffect(.degrees(open ? 90 : 0))
                }.foregroundStyle(status == .failed ? theme.destructive : theme.mutedForeground)
                    .modifier(triggerRow)
            }.buttonStyle(.plain).accessibilityLabel(title)
                .accessibilityValue(open ? "Expanded" : "Collapsed")
            content.environment(\.aiAnimationsActive, open && parentAnimations)
                .environment(\.aiParagraphMuted, true).environment(\.aiParagraphLineHeight, 22.75).aiFont().foregroundStyle(theme.mutedForeground)
                .padding(.leading, 17).padding(.trailing, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { Rectangle().fill(theme.border).frame(width: 1) }
                .padding(.leading, 7).padding(.top, density == .comfortable ? 0 : 8).padding(.bottom, 4)
                .frame(height: open ? nil : 0, alignment: .top).clipped()
                .opacity(open ? 1 : 0).allowsHitTesting(open).accessibilityHidden(!open)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StepRows: View {
    var steps: [AIStep]
    var customContent: ((AIStep) -> AnyView)? = nil
    var body: some View {
        AITrace {
            ForEach(steps) { step in
                if step.detail != nil || step.content != nil || customContent != nil {
                    AITraceDisclosure(step.title, icon: step.icon ?? step.status.icon, status: step.status, autoExpand: step.status == .failed) {
                        if let customContent { customContent(step) }
                        else if let content = step.content { detail(content) }
                        else if let text = step.detail { Text(text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                    }
                } else { AITraceLine(step.title, icon: step.icon ?? step.status.icon, status: step.status) }
            }
        }
    }
    @ViewBuilder private func detail(_ content: AIStepDetail) -> some View {
        switch content {
        case .text(let text): Text(text).textSelection(.enabled)
        case .markdown(let text): AIMessageResponse(text)
        case .code(let code, let language): AICodeBlock(code, language: language, wrap: true)
        case .sources(let sources):
            AIFlowLayout(spacing: 6) {
                ForEach(AISource.unique(sources)) { source in Link(destination: source.url) { AIBadge(source.hostname) } }
            }
        }
    }
}

public struct AIChainOfThought: View {
    public var title: String?
    public var steps: [AIStep]
    public var defaultOpen: Bool?
    public var isExpanded: Binding<Bool>?
    public var stepContent: ((AIStep) -> AnyView)?
    public init(title: String? = nil, steps: [AIStep], defaultOpen: Bool? = nil, isExpanded: Binding<Bool>? = nil, stepContent: ((AIStep) -> AnyView)? = nil) {
        self.title = title; self.steps = steps; self.defaultOpen = defaultOpen; self.isExpanded = isExpanded; self.stepContent = stepContent
    }
    public var body: some View {
        let status = AIStatus.aggregate(steps.map(\.status))
        let summary = title ?? (status == .running ? "Researching" : status == .pending ? "Waiting to research" : status == .failed ? "Researched in \(steps.count) \(steps.count == 1 ? "step" : "steps"), \(steps.filter { $0.status == .failed }.count) failed" : status == .denied ? "Research denied" : "Researched in \(steps.count) steps")
        AITraceDisclosure(summary, icon: status.icon, status: status, defaultOpen: defaultOpen, isExpanded: isExpanded, autoExpand: status == .running) { StepRows(steps: steps, customContent: stepContent) }
    }
}
public struct AIReasoning: View {
    public var text: String
    public var isStreaming: Bool
    public var duration: TimeInterval?
    public var isExpanded: Binding<Bool>?
    public var rendersMarkdown: Bool
    public init(_ text: String, isStreaming: Bool = false, duration: TimeInterval? = nil, isExpanded: Binding<Bool>? = nil, rendersMarkdown: Bool = false) {
        self.text = text; self.isStreaming = isStreaming; self.duration = duration; self.isExpanded = isExpanded; self.rendersMarkdown = rendersMarkdown
    }
    private var title: String {
        if isStreaming { return "Thinking" }
        guard let duration, duration.isFinite else { return "Thought" }
        return "Thought for \(Int(min(Double(Int.max / 2), max(0, duration))))s"
    }
    public var body: some View {
        if text.isEmpty { AITraceLine(title, icon: nil, status: isStreaming ? .running : .completed) }
        else {
            AITraceDisclosure(title, icon: nil, status: isStreaming ? .running : .completed, isExpanded: isExpanded, autoExpand: isStreaming) {
                if rendersMarkdown { AIMessageResponse(text) }
                else { NativeTextParagraph(verbatim: text).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }
}
public struct AIPlan: View {
    public var title: String
    public var steps: [AIStep]
    public var description: String?
    public var defaultOpen: Bool?
    public var isExpanded: Binding<Bool>?
    public var stepContent: ((AIStep) -> AnyView)?
    public init(_ title: String, steps: [AIStep], description: String? = nil, defaultOpen: Bool? = true, isExpanded: Binding<Bool>? = nil, stepContent: ((AIStep) -> AnyView)? = nil) {
        self.title = title; self.steps = steps; self.description = description; self.defaultOpen = defaultOpen; self.isExpanded = isExpanded; self.stepContent = stepContent
    }
    public var body: some View {
        AITraceDisclosure("Plan: \(title)", icon: .route, status: AIStatus.aggregate(steps.map(\.status)),
                          detail: "\(steps.filter { $0.status == .completed }.count) of \(steps.count) done", defaultOpen: defaultOpen, isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if let description { Text(description).fixedSize(horizontal: false, vertical: true) }
                StepRows(steps: steps, customContent: stepContent)
            }
        }
    }
}
public struct AIQueue: View {
    public var items: [AIStep]
    public var onSelect: ((AIStep) -> Void)?
    public init(items: [AIStep], onSelect: ((AIStep) -> Void)? = nil) { self.items = items; self.onSelect = onSelect }
    public var body: some View {
        AITrace {
            group(items.filter { $0.status != .completed }, done: false)
            group(items.filter { $0.status == .completed }, done: true)
            if items.isEmpty { Text("All caught up.").aiFont().foregroundStyle(.secondary) }
        }
    }
    @ViewBuilder private func group(_ rows: [AIStep], done: Bool) -> some View {
        if !rows.isEmpty {
            AITraceDisclosure("\(rows.count) \(done ? "completed" : "to do")", icon: done ? .listChecks : .listTodo, defaultOpen: !done || items.allSatisfy { $0.status == .completed }) {
                AITrace {
                    ForEach(rows) { row in
                        if row.detail != nil || row.content != nil {
                            StepRows(steps: [row])
                            if let onSelect { Button("Select \(row.title)") { onSelect(row) }.buttonStyle(AIButtonStyle(.ghost, compact: true)) }
                        } else if let onSelect {
                            Button { onSelect(row) } label: { queueLine(row).aiHitTarget() }.buttonStyle(.plain)
                        } else { queueLine(row) }
                    }
                }
            }
        }
    }
    private func queueLine(_ row: AIStep) -> some View {
        AITraceLine(row.title, icon: row.icon ?? row.status.icon, status: row.status, dimsPending: false)
    }
}
public struct AITask: View {
    public var title: String
    public var steps: [AIStep]
    public var status: AIStatus?
    public var runningTitle: String?
    public var failedTitle: String?
    public var defaultOpen: Bool?
    public var isExpanded: Binding<Bool>?
    public var stepContent: ((AIStep) -> AnyView)?
    public init(_ title: String, steps: [AIStep], status: AIStatus? = nil, runningTitle: String? = nil, failedTitle: String? = nil, defaultOpen: Bool? = nil, isExpanded: Binding<Bool>? = nil, stepContent: ((AIStep) -> AnyView)? = nil) {
        self.title = title; self.steps = steps; self.status = status; self.runningTitle = runningTitle; self.failedTitle = failedTitle; self.defaultOpen = defaultOpen; self.isExpanded = isExpanded; self.stepContent = stepContent
    }
    public var body: some View {
        let state = status ?? (steps.contains { $0.status == .failed } ? .failed : AIStatus.aggregate(steps.map(\.status)))
        let label = state == .running ? (runningTitle ?? title) : state == .failed ? (failedTitle ?? "Failed: \(title)") : title
        AITraceDisclosure(label, icon: state.icon, status: state, defaultOpen: defaultOpen, isExpanded: isExpanded, autoExpand: state == .running || state == .failed) { StepRows(steps: steps, customContent: stepContent) }
    }
}
public struct AISubagent<Content: View>: View {
    public var name: String
    public var status: AIStatus
    public var result: String?
    public var task: String?
    public var model: String?
    public var tools: [String]
    public var duration: TimeInterval?
    public var defaultOpen: Bool?
    public var isExpanded: Binding<Bool>?
    private let content: Content
    public init(_ name: String, status: AIStatus = .completed, result: String? = nil, task: String? = nil, model: String? = nil, tools: [String] = [], duration: TimeInterval? = nil, defaultOpen: Bool? = nil, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) {
        self.name = name; self.status = status; self.result = result; self.task = task; self.model = model; self.tools = tools; self.duration = duration; self.defaultOpen = defaultOpen; self.isExpanded = isExpanded; self.content = content()
    }
    public var body: some View {
        AITraceDisclosure("\(status.verb) the \(name) subagent", icon: status == .running ? .loaderCircle : status.icon, status: status, detail: duration.flatMap { $0.isFinite ? String(format: "%.1fs", max(0, $0)) : nil }, defaultOpen: defaultOpen, isExpanded: isExpanded, autoExpand: status == .running || status == .failed) {
            VStack(alignment: .leading, spacing: 12) {
                if let task { Text(task).fixedSize(horizontal: false, vertical: true) }
                if model != nil || !tools.isEmpty {
                    AIFlowLayout(spacing: 6) {
                        if let model { AIBadge(model) }
                        ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in AIBadge(tool) }
                    }
                }
                content
                if let result { AIMessageResponse(result) }
            }
        }
    }
}
