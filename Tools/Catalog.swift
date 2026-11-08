import Foundation

public struct Component: Codable {
    public let id: String
    public let name: String
    public let symbols: [String]
    public let summary: String
    public let notes: [String]
    public let sourceFiles: [String]
    public let exampleFile: String
    public let upstream: String
}

public struct Catalog: Codable {
    public let schemaVersion: Int
    public let repository: String
    public let attribution: String
    public let components: [Component]

    public static func bundled() throws -> Catalog {
        let url = try resource("Catalog/catalog.json")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    public func component(_ query: String) throws -> Component {
        let query = query.lowercased()
        guard let match = components.first(where: {
            $0.id == query || $0.name.lowercased() == query || $0.symbols.contains { $0.lowercased() == query }
        }) else { throw CLIError.usage("Unknown component '\(query)'. Run aielements list.") }
        return match
    }

    public func example(_ component: Component) throws -> String {
        try String(contentsOf: Self.resource("Catalog/Examples/\(component.exampleFile)"), encoding: .utf8)
    }

    static func resource(_ path: String) throws -> URL {
        guard let root = Bundle.module.resourceURL else { throw CLIError.io("Missing CLI resource bundle.") }
        let url = root.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.io("Missing resource \(path). Keep the .bundle next to the CLI executable.")
        }
        return url
    }
}
