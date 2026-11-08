import SwiftUI
@_exported import AIElementsUIProtocol

@MainActor public final class AIUIStore: ObservableObject {
    @Published public private(set) var session = AIUISession()
    @Published public private(set) var validationError: String?
    private var decoder = AIUIStreamDecoder()
    public init() {}
    public func load(_ document: AIUIDocument) throws {
        session = try AIUISession(document: document); validationError = nil; decoder.reset()
    }
    public func reset() { session = AIUISession(); decoder.reset(); validationError = nil }
    public func apply(_ event: AIUIStreamEvent) throws {
        do { try session.apply(event); validationError = nil }
        catch { validationError = error.localizedDescription; throw error }
    }
    public func receive(_ bytes: Data) throws {
        do { try decoder.append(bytes) { try session.apply($0) }; validationError = nil }
        catch { session.interrupt(error.localizedDescription); validationError = error.localizedDescription; throw error }
    }
    public func finish() throws {
        do {
            for event in try decoder.finish() { try apply(event) }
            session.interrupt("Generation ended before completion. Retry to generate a new surface.")
        } catch { session.interrupt(error.localizedDescription); validationError = error.localizedDescription; throw error }
    }
    public func interrupt(_ message: String = "Generation interrupted. Retry to generate a new surface.") { session.interrupt(message) }
    public func setValue(_ value: AIUIValue, nodeID: String) {
        do { try session.setValue(value, nodeID: nodeID); validationError = nil }
        catch { validationError = error.localizedDescription }
    }
}

/// Embed in AIMessage/AIChat or any native screen. The host handles returned actions.
public struct AIUIRenderer: View {
    @ObservedObject public var store: AIUIStore
    public var onEvent: ((AIUIEvent) -> Void)?
    @Theme private var theme
    public init(store: AIUIStore, onEvent: ((AIUIEvent) -> Void)? = nil) { self.store = store; self.onEvent = onEvent }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let document = store.session.document { render(document.root, document: document) }
            else if store.session.phase != .removed { placeholder }
            if let error = store.validationError ?? store.session.errorMessage {
                Text(error).aiFont(12).foregroundStyle(theme.destructive).accessibilityLabel("Generation error: \(error)")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8).fill(theme.muted).frame(height: 44)
            .accessibilityLabel("Generating interface")
    }
    private func render(_ id: String, document: AIUIDocument) -> AnyView {
        guard let node = document.nodes[id] else { return AnyView(placeholder.id(id)) }
        return AnyView(UIRenderNode(id: id, node: node, document: document, store: store, onEvent: onEvent,
                                    child: { render($0, document: document) }).id(id))
    }
}

private struct UIRenderNode: View {
    let id: String
    let node: AIUINode
    let document: AIUIDocument
    @ObservedObject var store: AIUIStore
    var onEvent: ((AIUIEvent) -> Void)?
    var child: (String) -> AnyView
    @Theme private var theme
    @Environment(\.colorScheme) private var scheme
    private var props: [String: AIUIValue] { node.resolved(in: document.state) }
    private func text(_ key: String, _ fallback: String = "") -> String { props[key]?.string ?? fallback }
    private var children: [String] { node.children ?? [] }
    private var variant: AIFoundationVariant { .init(rawValue: text("variant", "primary")) ?? .primary }
    private var disabled: Bool { props["disabled"]?.bool ?? false }
    private func emit(_ event: String, value: AIUIValue? = nil) {
        if let event = store.session.event(nodeID: id, event: event, value: value) { onEvent?(event) }
    }
    private var stringBinding: Binding<String> {
        Binding(get: { text("value") }, set: { value in store.setValue(.string(value), nodeID: id); emit("change", value: .string(value)) })
    }
    @ViewBuilder var body: some View {
        switch node.type {
        case "Stack": VStack(alignment: .leading, spacing: props["gap"]?.number ?? 16) { ForEach(children, id: \.self) { child($0) } }
        case "Row":
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: props["gap"]?.number ?? 12) { ForEach(children, id: \.self) { child($0) } }
                VStack(alignment: .leading, spacing: props["gap"]?.number ?? 12) { ForEach(children, id: \.self) { child($0) } }
            }
        case "Card":
            AICard(props["title"]?.string, description: props["description"]?.string, footer: props["footer"]?.string, footnote: props["footnote"]?.string, footerIcon: text("footerIcon") == "trending-up" ? .trendingUp : nil, style: .init(rawValue: text("style")) ?? .standard) {
                VStack(alignment: .leading, spacing: 16) { ForEach(children, id: \.self) { child($0) } }
            }
        case "Text":
            if ["body", "muted", ""].contains(text("variant")) {
                NativeTextParagraph(verbatim: text("text"))
                    .environment(\.aiParagraphLineHeight, 20)
                    .environment(\.aiParagraphMuted, text("variant") == "muted")
            } else {
                AITextLabel(text("text"), size: text("variant") == "title" ? 20 : text("variant") == "caption" ? 12 : 14,
                            weight: text("variant") == "title" ? .semibold : text("variant") == "label" ? .medium : .regular,
                            color: text("variant") == "caption" ? theme.mutedForeground : theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, text("variant") == "label" ? -2 : 0)
            }
        case "Badge":
            AITextLabel(text("text"), size: 12, weight: .medium,
                        color: variant == .primary ? (theme.primaryButtonLabel ?? theme.background) : variant == .destructive ? theme.destructive : theme.foreground)
                .padding(.horizontal, 9).frame(minHeight: 20)
                .background(variant == .primary ? (theme.primaryButtonFill ?? theme.foreground) : variant == .destructive ? theme.destructive.opacity(scheme == .dark ? 0.2 : 0.1) : [.outline, .ghost].contains(variant) ? .clear : theme.muted, in: Capsule())
                .overlay(Capsule().strokeBorder(variant == .outline ? theme.border : .clear, lineWidth: 1))
        case "Button":
            Button { emit("press") } label: {
                AITextLabel(text("label"), weight: .medium, color: variant == .primary ? (theme.primaryButtonLabel ?? theme.background) : variant == .destructive ? theme.destructive : theme.foreground)
            }.buttonStyle(AIFoundationButtonStyle(variant))
                .disabled(disabled || onEvent == nil || node.events?["press"] == nil || store.session.phase == .failed)
        case "Input": AIInput(text("label"), text: stringBinding, placeholder: text("placeholder")).disabled(disabled || node.bindings?["value"] == nil)
        case "Select":
            AISelect(text("label"), options: (props["options"]?.array ?? []).compactMap {
                guard let item = $0.object, let value = item["value"]?.string, let label = item["label"]?.string else { return nil }
                return AISelectOption(value, label: label)
            }, selection: stringBinding, placeholder: text("placeholder", "Select…")).disabled(disabled || node.bindings?["value"] == nil)
        case "Switch":
            AISwitch(text("label"), isOn: Binding(get: { props["value"]?.bool ?? false }, set: {
                store.setValue(.bool($0), nodeID: id); emit("change", value: .bool($0))
            })).disabled(disabled || node.bindings?["value"] == nil)
        case "Progress": AIProgress(value: props["value"]?.number ?? 0, total: props["max"]?.number ?? 100, label: props["label"]?.string)
        case "Separator": Rectangle().fill(theme.border).frame(height: 1).accessibilityHidden(true)
        case "Table": table
        case "BarChart", "LineChart", "AreaChart":
            if let height = props["height"]?.number { chart.frame(height: height) }
            else { chart.aspectRatio(16 / 9, contentMode: .fit) }
        default: EmptyView() // Validation rejects unsupported types before rendering.
        }
    }
    private var chart: some View {
        let series = (props["series"]?.array ?? []).compactMap { item -> AIChartSeries? in
            guard let object = item.object, let key = object["key"]?.string, let label = object["label"]?.string else { return nil }
            return .init(key, label: label)
        }
        let rows = (props["data"]?.array ?? []).compactMap { item -> AIChartRow? in
            guard let object = item.object, let label = object["label"]?.string else { return nil }
            return .init(label, values: object.compactMapValues(\.number))
        }
        return AIChart(node.type == "BarChart" ? .bar : node.type == "LineChart" ? .line : .area,
                       data: rows, series: series, label: text("label", "Chart"), showsLegend: props["legend"]?.bool ?? false) { row in
            var value = row.values.mapValues(AIUIValue.number); value["label"] = .string(row.label)
            emit("select", value: .object(value))
        }
    }
    private var table: some View {
        AITable(columns: (props["columns"]?.array ?? []).compactMap { value in
            guard let column = value.object, let key = column["key"]?.string, let label = column["label"]?.string else { return nil }
            return AITableColumn(key, label: label, width: column["width"]?.number,
                                 alignment: column["alignment"]?.string == "trailing" ? .trailing : .leading,
                                 emphasized: column["emphasized"]?.bool ?? false)
        }, rows: (props["rows"]?.array ?? []).compactMap { $0.object?.mapValues(\.displayText) },
        caption: props["caption"]?.string, footer: props["footer"]?.object?.mapValues(\.displayText))
    }

}

struct ChatUISurface: View {
    var document: AIUIDocument
    var onEvent: ((AIUIEvent) -> Void)?
    @StateObject private var store = AIUIStore()
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading) {
            AIUIRenderer(store: store, onEvent: onEvent)
            if let error { Text(error).font(AITypography.font(12)).foregroundStyle(.red) }
        }.onChange(of: document, initial: true) { _, value in
            do { try store.load(value); error = nil } catch { self.error = error.localizedDescription }
        }
    }
}
