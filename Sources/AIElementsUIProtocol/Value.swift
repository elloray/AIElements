import Foundation

/// JSON values only; no expressions, HTML, scripts, or executable commands.
public indirect enum AIUIValue: Codable, Hashable, Sendable {
    case string(String), number(Double), bool(Bool), array([AIUIValue]), object([String: AIUIValue]), null

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let array = try? value.decode([AIUIValue].self) { self = .array(array) }
        else { self = .object(try value.decode([String: AIUIValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let item): try value.encode(item)
        case .number(let item): try value.encode(item)
        case .string(let item): try value.encode(item)
        case .array(let item): try value.encode(item)
        case .object(let item): try value.encode(item)
        }
    }
    public var string: String? { if case .string(let value) = self { return value }; return nil }
    public var number: Double? { if case .number(let value) = self { return value }; return nil }
    public var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
    public var array: [AIUIValue]? { if case .array(let value) = self { return value }; return nil }
    public var object: [String: AIUIValue]? { if case .object(let value) = self { return value }; return nil }
    public var displayText: String {
        switch self {
        case .string(let value): value
        case .number(let value): value.formatted(.number.grouping(.never))
        case .bool(let value): value ? "Yes" : "No"
        case .null: "—"
        default: ""
        }
    }
}

public struct AIUIAction: Codable, Hashable, Sendable {
    public var name: String
    public var payload: [String: AIUIValue]?
    /// Explicitly chosen local state keys to include in the event; no implicit full-state export.
    public var stateKeys: [String]?
    public init(_ name: String, payload: [String: AIUIValue]? = nil, stateKeys: [String]? = nil) {
        self.name = name; self.payload = payload; self.stateKeys = stateKeys
    }
}

public struct AIUIEvent: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var version = "1.0"
    public var surfaceID: String
    public var revision: Int
    public var nodeID: String
    public var name: String
    public var event: String
    public var value: AIUIValue?
    public var payload: [String: AIUIValue]
    public var state: [String: AIUIValue]
    public init(surfaceID: String, revision: Int, nodeID: String, name: String, event: String,
                value: AIUIValue? = nil, payload: [String: AIUIValue] = [:], state: [String: AIUIValue] = [:]) {
        id = UUID().uuidString; self.surfaceID = surfaceID; self.revision = revision
        self.nodeID = nodeID; self.name = name; self.event = event; self.value = value
        self.payload = payload; self.state = state
    }
}

public struct AIUINode: Codable, Hashable, Sendable {
    public var type: String
    public var props: [String: AIUIValue]?
    public var children: [String]?
    /// Maps a property name to a flat local state key. No executable expression language.
    public var bindings: [String: String]?
    public var events: [String: AIUIAction]?
    public init(_ type: String, props: [String: AIUIValue]? = nil, children: [String]? = nil,
                bindings: [String: String]? = nil, events: [String: AIUIAction]? = nil) {
        self.type = type; self.props = props; self.children = children; self.bindings = bindings; self.events = events
    }
    public func resolved(in state: [String: AIUIValue]) -> [String: AIUIValue] {
        var result = props ?? [:]
        for (key, path) in bindings ?? [:] { result[key] = state[path] }
        return result
    }
}

public struct AIUIDocument: Codable, Hashable, Sendable, Identifiable {
    public var version: String
    public var id: String
    public var revision: Int
    public var root: String
    public var nodes: [String: AIUINode]
    public var state: [String: AIUIValue]
    public init(id: String, revision: Int = 0, root: String, nodes: [String: AIUINode], state: [String: AIUIValue] = [:]) {
        version = "1.0"; self.id = id; self.revision = revision; self.root = root; self.nodes = nodes; self.state = state
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 1_048_576 else { throw AIUIError.invalid("UI document exceeds 1 MiB.") }
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }
}

public enum AIUIError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public enum AIUIResources {
    public static let exampleNames = ["dashboard", "stack", "row", "card", "text", "button", "badge", "input", "select", "switch", "progress", "separator", "table", "bar-chart", "line-chart", "area-chart"]
    public static func data(named name: String) throws -> Data {
        guard (exampleNames + ["schema", "dashboard-stream"]).contains(name) else { throw AIUIError.invalid("Unknown UI resource: \(name)") }
        let file = name == "dashboard-stream" ? "dashboard.jsonl" : "\(name).json"
        guard let url = Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Resources")
                ?? Bundle.module.url(forResource: file, withExtension: nil) else { throw AIUIError.invalid("Missing UI resource: \(name)") }
        return try Data(contentsOf: url)
    }
}
