import SwiftUI
import AIElements

struct GenerativeDemo: View {
    @StateObject private var store = AIUIStore()
    @State private var generation: Task<Void, Never>?
    @State private var result = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.session.phase == .streaming ? "Generating interface…" : store.session.phase == .failed ? "Generation stopped" : "Interactive report")
                    .font(AITypography.font(14, weight: .medium))
                Spacer()
                if store.session.phase == .streaming {
                    Button("Stop") { generation?.cancel(); store.interrupt("Stopped. Your partial report is still available.") }
                        .buttonStyle(AIFoundationButtonStyle(.outline))
                } else {
                    Button("Replay") { replay() }.buttonStyle(AIFoundationButtonStyle(.outline))
                }
            }
            AIMessage(role: .assistant) {
                AIUIRenderer(store: store) { event in
                    if event.name == "save_report" {
                        result = "Save requested: \(event.state["reportName"]?.string ?? "Report")"
                    } else if event.name == "select_month" {
                        result = "\(event.value?.object?["label"]?.string ?? "Month"): \(event.value?.object?["desktop"]?.displayText ?? "0") visitors"
                    } else { result = "Updated report settings" }
                }
            }
            if !result.isEmpty { Text(result).font(AITypography.font(13)).accessibilityLabel(result) }
        }.onAppear { replay() }.onDisappear { generation?.cancel() }
    }
    private func replay() {
        generation?.cancel(); store.reset(); result = ""
        generation = Task { @MainActor in
            do {
                let data = try AIUIResources.data(named: "dashboard-stream")
                for line in data.split(separator: 10) {
                    try Task.checkCancellation()
                    // Same byte decoder as a network response, including split JSON frames.
                    let frame = Data(line) + Data([10]); let split = frame.count / 2
                    try store.receive(frame.prefix(split))
                    try store.receive(frame.dropFirst(split))
                    try await Task.sleep(for: .milliseconds(450))
                }
                try store.finish()
            } catch is CancellationError { }
            catch { store.interrupt(error.localizedDescription); result = error.localizedDescription }
        }
    }
}

struct FoundationChartDemo: View {
    var kind: AIChartKind = .bar
    @StateObject private var store = AIUIStore()
    var body: some View {
        AIUIRenderer(store: store).onAppear {
            do {
                var document = try AIUIDocument.decode(AIUIResources.data(named: "bar-chart"))
                document.nodes["chart"]?.type = kind == .bar ? "BarChart" : kind == .line ? "LineChart" : "AreaChart"
                if kind != .bar { document.nodes[document.root]?.props?["title"] = .string(kind == .line ? "Line Chart" : "Area Chart") }
                try store.load(document)
            } catch { store.interrupt(error.localizedDescription) }
        }
    }
}

struct UIFixtureView: View {
    @StateObject private var store: AIUIStore
    init(name: String) {
        let store = AIUIStore()
        do {
            if ["partial", "interrupted"].contains(name) {
                let frames = try AIUIResources.data(named: "dashboard-stream").split(separator: 10)
                for line in frames.prefix(11) { try store.receive(Data(line) + Data([10])) }
                if name == "interrupted" { store.interrupt("Stopped. Your partial report is still available.") }
            } else {
                var document = try AIUIDocument.decode(AIUIResources.data(named: name == "dashboard" ? name : "bar-chart"))
                if name == "line-chart" || name == "area-chart" {
                    document.nodes["chart"]?.type = name == "line-chart" ? "LineChart" : "AreaChart"
                    document.nodes[document.root]?.props?["title"] = .string(name == "line-chart" ? "Line Chart" : "Area Chart")
                }
                try store.load(document)
            }
        } catch { assertionFailure(error.localizedDescription) }
        _store = StateObject(wrappedValue: store)
    }
    var body: some View { AIUIRenderer(store: store) { _ in } }
}

#if os(macOS)
import AppKit
@MainActor enum UIFixtureExporter {
    static func export() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".impeccable/review/streaming-ui")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["bar-chart", "line-chart", "area-chart", "dashboard", "partial", "interrupted"] {
            for scheme in [ColorScheme.light, .dark] {
                let theme: AITheme = scheme == .dark ? .dark : .light
                let view = UIFixtureView(name: name).frame(width: 360).fixedSize(horizontal: false, vertical: true)
                    .background(theme.background).environment(\.colorScheme, scheme).aiTheme(theme)
                let host = NSHostingView(rootView: view)
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                window.setContentSize(host.fittingSize); host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: root.appendingPathComponent("mac-\(name)-\(scheme == .dark ? "dark" : "light")-360.png"))
                }
                window.contentView = nil
            }
        }
        print("Exported streaming UI fixtures to \(root.path)")
    }
}
#endif
