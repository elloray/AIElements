import SwiftUI
import AIElements

/// Reproducible, same-content fixtures for the official foundation examples.
enum FoundationAudit {
    static let names = ["stack", "row", "card", "text", "button", "badge", "input", "select", "switch", "progress", "separator", "table", "bar-chart", "line-chart", "area-chart"]
    /// Measure the actual controls without the screenshot canvas or optional labels.
    static func control(_ name: String) -> AnyView {
        switch name {
        case "button": return AnyView(Button("Button") {}.buttonStyle(AIFoundationButtonStyle()))
        case "input": return AnyView(AIInput("", text: .constant(""), placeholder: "Enter text").frame(width: 320))
        case "select": return AnyView(AISelect("", options: [.init("apple", label: "Apple")], selection: .constant(""), placeholder: "Select a fruit").frame(width: 192))
        default: return AnyView(AISwitch("Airplane Mode", isOn: .constant(false)))
        }
    }
    static func document(_ name: String) throws -> AIUIDocument {
        if name.hasSuffix("chart") {
            var doc = try AIUIDocument.decode(AIUIResources.data(named: "bar-chart"))
            let kind = name == "bar-chart" ? "Bar" : name == "line-chart" ? "Line" : "Area"
            doc.nodes["chart"]?.type = kind + "Chart"
            doc.nodes[doc.root]?.props?["title"] = .string(kind + " Chart")
            if kind == "Area" {
                doc.nodes[doc.root]?.props?["description"] = .string("Showing total visitors for the last 6 months")
                doc.nodes[doc.root]?.props?["footnote"] = .string("January - June 2024")
            }
            return doc
        }
        var nodes: [String: AIUINode] = [:]
        var state: [String: AIUIValue] = [:]
        func node(_ type: String, _ props: [String: AIUIValue] = [:]) { nodes["root"] = .init(type, props: props) }
        let body = "A set of beautifully designed components that you can customize, extend, and build on."
        switch name {
        case "text": node("Text", ["text": .string(body)])
        case "button": nodes["root"] = .init("Button", props: ["label": .string("Button")], events: ["press": .init("demo")])
        case "badge", "row":
            let labels = ["Badge", "Secondary", "Destructive", "Outline"]
            let variants = ["primary", "secondary", "destructive", "outline"]
            nodes["root"] = .init("Row", props: ["gap": .number(8)], children: labels)
            for (i, label) in labels.enumerated() { nodes[label] = .init("Badge", props: ["text": .string(label), "variant": .string(variants[i])]) }
        case "stack":
            nodes["root"] = .init("Stack", props: ["gap": .number(16)], children: ["heading", "rule", "body"])
            nodes["heading"] = .init("Stack", props: ["gap": .number(6)], children: ["title", "description"])
            nodes["title"] = .init("Text", props: ["text": .string("shadcn/ui"), "variant": .string("label")])
            nodes["description"] = .init("Text", props: ["text": .string("The Foundation for your Design System"), "variant": .string("muted")])
            nodes["rule"] = .init("Separator"); nodes["body"] = .init("Text", props: ["text": .string(body)])
        case "input":
            nodes["root"] = .init("Input", props: ["placeholder": .string("Enter text")], bindings: ["value": "input"]); state["input"] = .string("")
        case "select":
            nodes["root"] = .init("Select", props: ["placeholder": .string("Select a fruit"), "options": .array(["Apple", "Banana", "Blueberry", "Grapes", "Pineapple"].map { .object(["value": .string($0.lowercased()), "label": .string($0)]) })], bindings: ["value": "fruit"]); state["fruit"] = .string("")
        case "switch":
            nodes["root"] = .init("Switch", props: ["label": .string("Airplane Mode")], bindings: ["value": "airplane"]); state["airplane"] = .bool(false)
        case "progress": node("Progress", ["value": .number(66)])
        case "separator": node("Separator")
        case "table":
            let data = [("INV001", "Paid", "Credit Card", "$250.00"), ("INV002", "Pending", "PayPal", "$150.00"), ("INV003", "Unpaid", "Bank Transfer", "$350.00"), ("INV004", "Paid", "Credit Card", "$450.00"), ("INV005", "Paid", "PayPal", "$550.00"), ("INV006", "Pending", "Bank Transfer", "$200.00"), ("INV007", "Unpaid", "Credit Card", "$300.00")]
            let columns: [AIUIValue] = ["Invoice", "Status", "Method", "Amount"].map { label in
                var item: [String: AIUIValue] = ["key": .string(label), "label": .string(label)]
                if label == "Invoice" { item["width"] = .number(100); item["emphasized"] = .bool(true) }
                if label == "Amount" { item["alignment"] = .string("trailing") }
                return .object(item)
            }
            node("Table", ["footer": .object(["Invoice": .string("Total"), "Amount": .string("$2,500.00")]), "caption": .string("A list of your recent invoices."), "columns": .array(columns), "rows": .array(data.map { .object(["Invoice": .string($0.0), "Status": .string($0.1), "Method": .string($0.2), "Amount": .string($0.3)]) })])
        case "card":
            nodes["root"] = .init("Card", props: ["title": .string("Login to your account"), "description": .string("Enter your email below to login to your account")], children: ["email", "password", "login", "google"])
            nodes["email"] = .init("Input", props: ["label": .string("Email"), "placeholder": .string("m@example.com")], bindings: ["value": "email"])
            nodes["password"] = .init("Input", props: ["label": .string("Password")], bindings: ["value": "password"])
            nodes["login"] = .init("Button", props: ["label": .string("Login")], events: ["press": .init("login")])
            nodes["google"] = .init("Button", props: ["label": .string("Login with Google"), "variant": .string("outline")], events: ["press": .init("google")])
            state = ["email": .string(""), "password": .string("")]
        default: node("Text", ["text": .string("Unknown fixture")])
        }
        return AIUIDocument(id: name, root: "root", nodes: nodes, state: state)
    }
}

struct FoundationAuditView: View {
    var name: String
    @StateObject private var store: AIUIStore
    init(name: String) {
        self.name = name
        let store = AIUIStore()
        do { try store.load(FoundationAudit.document(name)) } catch { assertionFailure(error.localizedDescription) }
        _store = StateObject(wrappedValue: store)
    }
    private var control: Bool { ["button", "badge", "row", "input", "select", "switch", "progress", "separator"].contains(name) }
    var body: some View {
        Group {
            if name == "card" { FoundationLoginCard() }
            else if ["button", "badge", "row", "switch"].contains(name) { AIUIRenderer(store: store) { _ in }.fixedSize(horizontal: true, vertical: true) }
            else { AIUIRenderer(store: store) { _ in }.frame(width: name == "select" ? 192 : name == "input" ? 320 : name == "progress" ? 216 : 360) }
        }.frame(width: 360, height: control ? 64 : nil, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FoundationLoginCard: View {
    @State private var email = ""
    @State private var password = ""
    @State private var result = ""
    @Environment(\.colorScheme) private var scheme
    private var theme: AITheme { scheme == .dark ? .dark : .light }
    var body: some View {
        AICard("Login to your account", description: "Enter your email below to login to your account",
               headerAction: AnyView(Button { result = "Sign up" } label: { AITextLabel("Sign Up", weight: .medium) }.buttonStyle(AIFoundationButtonStyle(.ghost))),
               footerContent: AnyView(VStack(spacing: 8) {
            Button { result = "Login" } label: { AITextLabel("Login", weight: .medium, color: theme.primaryButtonLabel ?? theme.background).frame(maxWidth: .infinity) }.buttonStyle(AIFoundationButtonStyle())
            Button { result = "Google" } label: { AITextLabel("Login with Google", weight: .medium).frame(maxWidth: .infinity) }.buttonStyle(AIFoundationButtonStyle(.outline))
        })) {
            VStack(spacing: 24) {
                AIInput("Email", text: $email, placeholder: "m@example.com")
                AIInput("Password", text: $password, secure: true,
                        labelAccessory: AnyView(Button { result = "Reset password" } label: { AITextLabel("Forgot your password?") }
                            .buttonStyle(.plain).foundationLinkTarget()))
            }
        }.accessibilityValue(result)
    }
}
private extension View {
    @ViewBuilder func foundationLinkTarget() -> some View {
        #if os(iOS)
        self.frame(minHeight: 44).contentShape(Rectangle())
        #else
        self.frame(minHeight: 20)
        #endif
    }
}

#if os(macOS)
import AppKit
@MainActor enum FoundationAuditExporter {
    static func export() {
        let args = CommandLine.arguments
        let folder = args.firstIndex(of: "--output").map { args[$0 + 1] } ?? ".build/foundation-audit/native"
        let root = URL(fileURLWithPath: folder); try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var controlSizes: [String: [String: CGFloat]] = [:]
        for name in ["button", "input", "select", "switch"] {
            let host = NSHostingView(rootView: FoundationAudit.control(name))
            let size = host.fittingSize
            controlSizes[name] = ["width": size.width, "height": size.height]
        }
        if let data = try? JSONSerialization.data(withJSONObject: controlSizes, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: root.appendingPathComponent("mac-control-sizes.json"))
        }
        for name in FoundationAudit.names {
            for scheme in [ColorScheme.light, .dark] {
                let theme: AITheme = scheme == .dark ? .dark : .light
                let host = NSHostingView(rootView: FoundationAuditView(name: name).background(theme.background).environment(\.colorScheme, scheme).aiTheme(theme))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host; window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize); host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                window.setContentSize(host.fittingSize); host.frame = NSRect(origin: .zero, size: host.fittingSize); host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: root.appendingPathComponent("mac-\(name)-\(scheme == .dark ? "dark" : "light").png"))
                }
                window.contentView = nil
            }
        }
    }
}
#else
import UIKit
@MainActor enum FoundationAuditExporter {
    static func export() async {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("foundation-audit")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene); window.windowLevel = .alert + 1
        var controlSizes: [String: [String: CGFloat]] = [:]
        for name in ["button", "input", "select", "switch"] {
            let host = UIHostingController(rootView: FoundationAudit.control(name)); host.safeAreaRegions = []
            let size = host.sizeThatFits(in: CGSize(width: 360, height: 2000))
            controlSizes[name] = ["width": size.width, "height": size.height]
        }
        if let data = try? JSONSerialization.data(withJSONObject: controlSizes, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: root.appendingPathComponent("ios-control-sizes.json"))
        }
        for name in FoundationAudit.names {
            for scheme in [ColorScheme.light, .dark] {
                let theme: AITheme = scheme == .dark ? .dark : .light
                let view = FoundationAuditView(name: name).background(theme.background).environment(\.colorScheme, scheme).aiTheme(theme)
                let host = UIHostingController(rootView: view); host.safeAreaRegions = []; host.view.backgroundColor = UIColor(theme.background)
                let size = host.sizeThatFits(in: CGSize(width: 360, height: 2000))
                window.rootViewController = host; window.frame = CGRect(origin: CGPoint(x: 0, y: 100), size: size); window.isHidden = false
                host.view.frame = CGRect(origin: .zero, size: size); host.view.setNeedsLayout(); host.view.layoutIfNeeded()
                try? await Task.sleep(for: .milliseconds(250))
                let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true
                let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
                try? image.pngData()?.write(to: root.appendingPathComponent("ios-\(name)-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
        window.isHidden = true
        try? Data("complete".utf8).write(to: root.appendingPathComponent("complete"))
    }
}
#endif
