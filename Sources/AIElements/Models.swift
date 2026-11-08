import Foundation

public enum AIStatus: String, CaseIterable, Codable, Sendable {
    case pending, running, completed, failed, denied
    public var label: String { rawValue.capitalized }
    public var verb: String {
        switch self { case .pending: "Waiting to run"; case .running: "Running"; case .completed: "Ran"; case .failed: "Failed to run"; case .denied: "Denied" }
    }
    public var icon: AIIconName {
        switch self { case .pending: .circle; case .running: .circleDot; case .completed: .circleCheck; case .failed: .circleX; case .denied: .circleX }
    }
    public static func aggregate(_ statuses: [AIStatus]) -> AIStatus {
        if statuses.contains(.running) { return .running }
        if statuses.contains(.failed) { return .failed }
        if statuses.contains(.denied) { return .denied }
        if statuses.contains(.pending) || statuses.isEmpty { return .pending }
        return .completed
    }
}
public enum AIStepDetail: Equatable, Sendable {
    case text(String), markdown(String), code(String, language: String? = nil), sources([AISource])
}
public struct AIStep: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var detail: String?
    public var content: AIStepDetail?
    public var icon: AIIconName?
    public var status: AIStatus
    public init(id: String = UUID().uuidString, title: String, detail: String? = nil, status: AIStatus = .completed, icon: AIIconName? = nil, content: AIStepDetail? = nil) {
        self.id = id; self.title = title; self.detail = detail; self.status = status; self.icon = icon; self.content = content
    }
}
public struct AISource: Identifiable, Hashable, Sendable {
    public var id: String { url.absoluteString }
    public var title: String
    public var url: URL
    public var summary: String?
    public var hostname: String { url.host() ?? url.absoluteString }
    public init(title: String? = nil, url: URL, summary: String? = nil) {
        self.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title! : (url.host() ?? url.absoluteString)
        self.url = url; self.summary = summary
    }
    public static func unique(_ sources: [AISource]) -> [AISource] {
        var seen = Set<URL>(); return sources.filter { seen.insert($0.url).inserted }
    }
}
public struct AIModel: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var provider: String
    public var supportedEfforts: [AIEffort]
    public init(id: String, name: String, provider: String, supportedEfforts: [AIEffort] = AIEffort.allCases) { self.id = id; self.name = name; self.provider = provider; self.supportedEfforts = supportedEfforts }
}
extension AIModel {
    static func selected(in models: [AIModel], id: String) -> AIModel? {
        models.first { $0.id == id } ?? models.first
    }

    func resolvedEffort(_ effort: AIEffort) -> AIEffort {
        supportedEfforts.contains(effort) ? effort : supportedEfforts.first ?? effort
    }
}
public enum AIEffort: String, CaseIterable, Sendable { case low, medium, high }
public struct AIAttachment: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var url: URL?
    public var byteCount: Int64?
    public var data: Data?
    public var mediaType: String?
    public init(id: String = UUID().uuidString, name: String, url: URL? = nil, byteCount: Int64? = nil, data: Data? = nil, mediaType: String? = nil) {
        self.id = id; self.name = name; self.url = url; self.byteCount = byteCount; self.data = data; self.mediaType = mediaType
    }
}
public struct AIContextUsage: Equatable, Sendable {
    public var input: Int
    public var output: Int
    public var reasoning: Int
    public var limit: Int
    public init(input: Int, output: Int, reasoning: Int = 0, limit: Int) {
        self.input = max(0, input); self.output = max(0, output); self.reasoning = max(0, reasoning); self.limit = max(0, limit)
    }
    public var used: Double { Double(max(0, input)) + Double(max(0, output)) + Double(max(0, reasoning)) }
    public var fraction: Double { limit > 0 ? min(1, max(0, used / Double(limit))) : 0 }
    public var percent: Int { Int((fraction * 100).rounded()) }
    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value < 1000 { return String(Int(max(0, value))) }
        let result = String(format: "%.1f", value / 1000)
        return (result.hasSuffix(".0") ? String(result.dropLast(2)) : result) + "k"
    }
}
public struct AIFileNode: Identifiable, Equatable, Sendable {
    public var id: String { path }
    public var path: String
    public var name: String
    /// nil is a file, an empty array is an empty folder.
    public var children: [AIFileNode]?
    public init(path: String, name: String? = nil, children: [AIFileNode]? = nil) {
        self.path = path; self.name = name ?? (path as NSString).lastPathComponent; self.children = children
    }
}
public enum AIMessageRole: String, Codable, Hashable, Sendable { case user, assistant, system }
public enum AIMessagePart: Hashable, Sendable {
    case ui(AIUIDocument)
    case text(String)
    case reasoning(text: String, isStreaming: Bool, duration: TimeInterval? = nil)
    case tool(name: String, status: AIStatus, input: String? = nil, output: String? = nil)
    case toolApproval(id: String, name: String, input: String? = nil)
    case attachment(AIAttachment)
    case sources([AISource])
}
public struct AIChatMessage: Identifiable, Hashable, Sendable {
    public var id: String
    public var role: AIMessageRole
    public var text: String
    public var parts: [AIMessagePart]
    public var copyableText: String {
        ([text] + parts.compactMap { part in
            guard case .text(let body) = part else { return nil }
            return body
        }).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
    public init(id: String = UUID().uuidString, role: AIMessageRole, text: String = "", parts: [AIMessagePart] = []) { self.id = id; self.role = role; self.text = text; self.parts = parts }
}
public enum AITestStatus: String, Sendable { case passed, failed, skipped }
public struct AITestCase: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var status: AITestStatus
    public var error: String?
    public init(id: String = UUID().uuidString, name: String, status: AITestStatus, error: String? = nil) {
        self.id = id; self.name = name; self.status = status; self.error = error
    }
}
public struct AITestSuite: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var tests: [AITestCase]
    public init(id: String = UUID().uuidString, name: String, tests: [AITestCase]) { self.id = id; self.name = name; self.tests = tests }
    public var failedCount: Int { tests.filter { $0.status == .failed }.count }
}

/// Provider-neutral adapter for tool lifecycle; UI does not depend on an AI SDK.
public enum AIToolPhase: Sendable {
    case inputStreaming, inputAvailable, approvalRequested, approvalResponded(approved: Bool), outputAvailable(preliminary: Bool), outputError, outputDenied
    public func status(streaming: Bool, clientTool: Bool = false) -> AIStatus {
        switch self {
        case .inputStreaming, .inputAvailable: return streaming ? .running : (clientTool ? .pending : .failed)
        case .approvalRequested: return .pending
        case .approvalResponded(let approved): return approved ? .running : .denied
        case .outputAvailable(let preliminary): return preliminary ? (streaming ? .running : .failed) : .completed
        case .outputError: return .failed
        case .outputDenied: return .denied
        }
    }
}
