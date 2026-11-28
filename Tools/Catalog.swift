import Foundation
import AIElementsCatalog

public struct Component: Codable {
    public let id: String
    public let name: String
    public let symbols: [String]
    public let summary: String
    public let notes: [String]
    public let sourceFiles: [String]
    public let exampleFile: String
    public let upstream: String
    /// Present for the 15 JSON protocol nodes; symbols only name actual Swift APIs.
    public let protocolType: String?
    public var shadcnID: String? = nil
}

public struct Catalog: Codable {
    public let schemaVersion: Int
    public let repository: String
    public let attribution: String
    public let components: [Component]

    public static func bundled() throws -> Catalog {
        let url = try resource("Catalog/catalog.json")
        let existing = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        let official = AIShadcnCatalog.examples.map { entry in
            let name = entry.id.split(separator: "-").map { $0.capitalized }.joined()
            return Component(id: "shadcn-" + entry.id, name: "shadcn/ui " + entry.title,
                             symbols: ["AIShadcnView"], summary: entry.summary,
                             notes: ["Bind values to own the state. onAction receives a control ID and its value."],
                             sourceFiles: ["Sources/AIElements/Shadcn/ShadcnView.swift", "Sources/AIElements/Shadcn/ShadcnControls.swift",
                                           "Sources/AIElements/Shadcn/ShadcnPanels.swift", "Sources/AIElementsCatalog/Resources/shadcn-catalog.json"],
                             exampleFile: "Shadcn" + name + "Example.swift", upstream: entry.source.absoluteString,
                             protocolType: nil, shadcnID: entry.id)
        }
        return Catalog(schemaVersion: existing.schemaVersion, repository: existing.repository,
                       attribution: existing.attribution, components: existing.components + official)
    }

    public func component(_ query: String) throws -> Component {
        let query = query.lowercased()
        if let match = components.first(where: {
            $0.id == query || $0.name.lowercased() == query || $0.protocolType?.lowercased() == query
        }) { return match }
        if let entry = components.first(where: { $0.shadcnID == query }) { return entry }
        let matches = components.filter { $0.symbols.contains { $0.lowercased() == query } }
        guard matches.count <= 1 else {
            throw CLIError.usage("Shared Swift symbol '\(query)'. Choose a component: \(matches.map(\.id).joined(separator: ", ")).")
        }
        guard let match = matches.first else { throw CLIError.usage("Unknown component '\(query)'. Run aielements list.") }
        return match
    }

    public func example(_ component: Component) throws -> String {
        if let id = component.shadcnID, let entry = AIShadcnCatalog.examples.first(where: { $0.id == id }) {
            return ShadcnExampleSource.file(entry, type: String(component.exampleFile.dropLast(6)))
        }
        return try String(contentsOf: Self.resource("Catalog/Examples/\(component.exampleFile)"), encoding: .utf8)
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
