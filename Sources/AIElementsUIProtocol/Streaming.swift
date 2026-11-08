import Foundation

/// Transport independent JSONL events. Feed decoded events from SSE, WebSocket, or raw bytes.
public struct AIUIStreamEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case begin = "surface.begin", update = "surface.update", complete = "surface.complete"
        case failure = "surface.error", remove = "surface.remove"
    }
    public var version: String
    public var kind: Kind
    public var surfaceID: String
    public var revision: Int
    public var baseRevision: Int?
    public var root: String?
    public var nodes: [String: AIUINode]?
    public var removeNodes: [String]?
    public var state: [String: AIUIValue]?
    public var message: String?
    public init(_ kind: Kind, surfaceID: String, revision: Int, baseRevision: Int? = nil,
                root: String? = nil, nodes: [String: AIUINode]? = nil, removeNodes: [String]? = nil,
                state: [String: AIUIValue]? = nil, message: String? = nil) {
        version = "1.0"; self.kind = kind; self.surfaceID = surfaceID; self.revision = revision
        self.baseRevision = baseRevision; self.root = root; self.nodes = nodes; self.removeNodes = removeNodes
        self.state = state; self.message = message
    }
}

/// Buffers partial UTF-8 and JSON. A network chunk is never assumed to be a JSON object.
public struct AIUIStreamDecoder {
    private var buffer = Data()
    public let maximumLineBytes: Int
    public init(maximumLineBytes: Int = 1_048_576) { self.maximumLineBytes = max(1, maximumLineBytes) }
    public mutating func append(_ bytes: Data) throws -> [AIUIStreamEvent] {
        var result: [AIUIStreamEvent] = []
        try append(bytes) { result.append($0) }
        return result
    }
    /// Delivers valid lines immediately, even when a later line in the same chunk is malformed.
    public mutating func append(_ bytes: Data, onEvent: (AIUIStreamEvent) throws -> Void) throws {
        buffer.append(bytes)
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard line.count <= maximumLineBytes else { throw AIUIError.invalid("UI stream line exceeds size limit.") }
            if !line.allSatisfy({ [9, 13, 32].contains($0) }) {
                try onEvent(JSONDecoder().decode(AIUIStreamEvent.self, from: line))
            }
        }
        guard buffer.count <= maximumLineBytes else { throw AIUIError.invalid("UI stream line exceeds size limit.") }
    }
    /// A final JSON object without a newline is accepted; truncated JSON throws.
    public mutating func finish() throws -> [AIUIStreamEvent] {
        if buffer.isEmpty { return [] }
        return try append(Data([10]))
    }
    public mutating func reset() { buffer.removeAll(keepingCapacity: false) }
}

/// One surface reducer. Host routes surfaceID to its own session; updates are transactional.
public struct AIUISession: Sendable {
    public enum Phase: String, Sendable { case idle, streaming, complete, failed, removed }
    public private(set) var document: AIUIDocument?
    public private(set) var phase: Phase = .idle
    public private(set) var errorMessage: String?
    private var surfaceID: String?
    private var lastRevision = -1
    public init() {}
    public init(document: AIUIDocument) throws {
        try document.validate()
        self.document = document; phase = .complete; surfaceID = document.id; lastRevision = document.revision
    }
    public mutating func apply(_ event: AIUIStreamEvent) throws {
        guard event.version == "1.0", !event.surfaceID.isEmpty, event.surfaceID.count <= 128,
              (0...9_007_199_254_740_991).contains(event.revision),
              (event.message?.utf8.count ?? 0) <= 32_768 else {
            throw AIUIError.invalid("Unsupported UI protocol version or invalid surface identity.")
        }
        if event.kind == .begin {
            guard phase == .idle || phase == .removed else { throw AIUIError.invalid("A surface already exists. Use update or create a new session.") }
            guard let root = event.root, !root.isEmpty else { throw AIUIError.invalid("surface.begin requires root.") }
            let next = AIUIDocument(id: event.surfaceID, revision: event.revision, root: root,
                                    nodes: event.nodes ?? [:], state: event.state ?? [:])
            try next.validate(allowIncomplete: true)
            document = next; phase = .streaming; surfaceID = event.surfaceID
            lastRevision = event.revision; errorMessage = nil
            return
        }
        guard event.surfaceID == surfaceID, event.baseRevision == lastRevision,
              event.revision == lastRevision + 1, var next = document else {
            throw AIUIError.invalid("Out-of-order UI event. Request a fresh surface snapshot.")
        }
        guard phase != .failed || event.kind == .remove else {
            throw AIUIError.invalid("Failed surface is frozen; remove it or start a new session to retry.")
        }
        if event.kind == .remove {
            document = nil; phase = .removed; lastRevision = event.revision; errorMessage = nil
            return
        }
        if event.kind == .failure {
            phase = .failed; errorMessage = event.message ?? "Generation interrupted. Retry to generate a new surface."
            next.revision = event.revision; document = next; lastRevision = event.revision
            return
        }
        if let root = event.root { next.root = root }
        for id in event.removeNodes ?? [] { next.nodes.removeValue(forKey: id) }
        for (id, node) in event.nodes ?? [:] { next.nodes[id] = node }
        // Only explicitly changed keys are replaced, preserving user edits during generation.
        for (key, value) in event.state ?? [:] { next.state[key] = value }
        next.revision = event.revision
        let incomplete = event.kind != .complete
        try next.validate(allowIncomplete: incomplete)
        document = next; lastRevision = event.revision; phase = incomplete ? .streaming : .complete; errorMessage = nil
    }
    /// Call when transport ends without surface.complete, or decoding/networking fails.
    public mutating func interrupt(_ message: String = "Generation interrupted. Retry to continue.") {
        guard phase == .streaming else { return }
        phase = .failed; errorMessage = message
    }
    public mutating func setValue(_ value: AIUIValue, nodeID: String, property: String = "value") throws {
        guard var next = document, let node = next.nodes[nodeID], let key = node.bindings?[property] else {
            throw AIUIError.invalid("Control has no state binding.")
        }
        next.state[key] = value
        try next.validate(allowIncomplete: phase == .streaming || phase == .failed)
        document = next
    }
    public func event(nodeID: String, event: String, value: AIUIValue? = nil) -> AIUIEvent? {
        guard let document, let action = document.nodes[nodeID]?.events?[event] else { return nil }
        return AIUIEvent(surfaceID: document.id, revision: document.revision, nodeID: nodeID,
                         name: action.name, event: event, value: value, payload: action.payload ?? [:],
                         state: document.state.filter { (action.stateKeys ?? []).contains($0.key) })
    }
}
