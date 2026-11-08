import Foundation
import AIElementsUIProtocol

public enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case io(String)

    public var description: String {
        switch self { case .usage(let text), .io(let text): return text }
    }
    public var exitCode: Int32 { if case .usage = self { return 2 }; return 1 }
}

/// No subprocesses, network access, or writes to an existing project.
public struct CLI {
    public static let version = "0.1.0"
    public init() {}

    public func run(_ arguments: [String], directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> String {
        var args = arguments
        let json = args.contains("--json")
        args.removeAll { $0 == "--json" }
        let command = args.isEmpty ? "help" : args.removeFirst()
        if ["help", "--help", "-h"].contains(command) {
            guard args.isEmpty else { throw CLIError.usage("Use aielements help for all command syntax.") }
            return json ? try encode(HelpResult(help: Self.help)) : Self.help
        }
        if ["version", "--version"].contains(command) {
            try noExtra(args)
            return json ? try encode(Version(version: Self.version)) : "aielements \(Self.version)"
        }
        let catalog = try Catalog.bundled()
        switch command {
        case "ui":
            guard let action = args.first else { throw CLIError.usage("Usage: aielements ui schema | example [dashboard|bar-chart] | stream | validate PATH") }
            args.removeFirst()
            switch action {
            case "schema", "stream", "example":
                let name: String
                if action == "example" {
                    name = args.isEmpty ? "dashboard" : args.removeFirst()
                    guard ["dashboard", "bar-chart"].contains(name) else { throw CLIError.usage("Unknown UI example. Use dashboard or bar-chart.") }
                } else { name = action == "stream" ? "dashboard-stream" : "schema" }
                try noExtra(args)
                return String(decoding: try AIUIResources.data(named: name), as: UTF8.self).trimmingCharacters(in: .newlines)
            case "validate":
                guard args.count == 1 else { throw CLIError.usage("Usage: aielements ui validate document.json | stream.jsonl") }
                let url = resolve(args[0], in: directory)
                let data = try Data(contentsOf: url)
                var revision = 0
                if url.pathExtension == "jsonl" {
                    var decoder = AIUIStreamDecoder(); var session = AIUISession()
                    try decoder.append(data) { try session.apply($0) }
                    for frame in try decoder.finish() { try session.apply(frame) }
                    guard session.phase == .complete || session.phase == .removed else { throw CLIError.usage("Stream did not complete successfully.") }
                    revision = session.document?.revision ?? 0
                } else { revision = try AIUIDocument.decode(data).revision }
                return json ? try encode(UIValidationResult(valid: true, revision: revision)) : "Valid UI \(url.lastPathComponent) (revision \(revision))"
            default: throw CLIError.usage("Unknown ui action '\(action)'.")
            }
        case "list":
            var query: String?
            if !args.isEmpty {
                guard args.count == 2, args[0] == "--search" else { throw CLIError.usage("Usage: aielements list [--search TEXT] [--json]") }
                query = args[1]
            }
            let items = catalog.components.filter { item in
                guard let query else { return true }
                return ([item.id, item.name, item.summary] + item.symbols).joined(separator: " ").localizedCaseInsensitiveContains(query)
            }
            return json ? try encode(ListResult(components: items)) : items.map { "\($0.id)\t\($0.symbols.joined(separator: ", "))\n  \($0.summary)" }.joined(separator: "\n")
        case "show", "example":
            guard args.count == 1 else { throw CLIError.usage("Usage: aielements \(command) COMPONENT [--json]") }
            let component = try catalog.component(args[0])
            let code = try catalog.example(component)
            if json { return try encode(ComponentResult(component: component, code: code, attribution: catalog.attribution)) }
            if command == "example" { return code }
            return """
            # \(component.name)
            \(component.summary)

            Symbols: \(component.symbols.joined(separator: ", "))
            Source: \(component.sourceFiles.joined(separator: ", "))
            Upstream design: \(component.upstream)
            \(catalog.attribution)

            \(component.notes.map { "- \($0)" }.joined(separator: "\n"))

            ```swift
            \(code)
            ```
            """
        case "init":
            let options = try Options(args, values: ["--path", "--name", "--local-package", "--revision"], flags: ["--dry-run"])
            let path = try options.required("--path")
            let name = options.values["--name"] ?? "AssistantUI"
            guard name.range(of: "^[A-Z][A-Za-z0-9]{0,63}$", options: .regularExpression) != nil else {
                throw CLIError.usage("--name must start with A–Z and contain only ASCII letters/digits (max 64).")
            }
            guard !["AIElements", "AIElementsCLIKit", "Swift", "SwiftUI", "Foundation"].contains(name) else {
                throw CLIError.usage("--name '\(name)' conflicts with a dependency module.")
            }
            guard options.values["--local-package"] == nil || options.values["--revision"] == nil else {
                throw CLIError.usage("Choose either --local-package or --revision.")
            }
            let dependency: String
            if let local = options.values["--local-package"] {
                let url = resolve(local, in: directory)
                guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
                    throw CLIError.usage("--local-package must contain Package.swift.")
                }
                dependency = ".package(name: \"AIElements\", path: \(swiftLiteral(url.path)))"
            } else if let revision = options.values["--revision"] {
                guard revision.range(of: "^[a-fA-F0-9]{40}$", options: .regularExpression) != nil else {
                    throw CLIError.usage("--revision requires a full 40-character Git commit SHA.")
                }
                dependency = ".package(url: \(swiftLiteral(catalog.repository)), revision: \(swiftLiteral(revision)))"
            } else {
                dependency = ".package(url: \(swiftLiteral(catalog.repository)), branch: \"main\")"
            }
            let files = [
                GeneratedFile(path: "Package.swift", content: Self.manifest(name: name, dependency: dependency)),
                GeneratedFile(path: "Sources/\(name)/AssistantChatView.swift", content: try catalog.example(catalog.component("chat"))),
                GeneratedFile(path: ".gitignore", content: ".build/\n.swiftpm/\n.DS_Store\n"),
                GeneratedFile(path: "README.md", content: """
                # \(name)

                A reusable SwiftUI feature package for iOS 17+ / macOS 14+.
                Add this local package to an existing Xcode app, link the \(name) product,
                then use `import \(name)` and `AssistantChatView()`.
                This is a UI package, not a standalone iOS app or Xcode project.

                The example accepts messages locally. Connect your own model service in
                onSubmit; preserve the draft and attachments until your service accepts them.
                There is no model SDK, command execution, or API key in the generated code.

                Verify with `swift build` on macOS and build your host app on an iOS simulator.
                If using the remote main branch, commit Package.resolved or pin a revision
                for reproducible builds.

                UI: [AIElements](https://github.com/elloray/AIElements), an unofficial SwiftUI
                port of [shadcn/ui AI Elements](https://ui.shadcn.com/docs/ai-elements).
                Independent of shadcn and Vercel. Preserve applicable upstream licenses:
                [third-party notices](https://github.com/elloray/AIElements/blob/main/THIRD_PARTY_NOTICES.md).
                """)
            ]
            return try materialize(files, path: path, in: directory, dryRun: options.flags.contains("--dry-run"), json: json)
        case "skill":
            guard !args.isEmpty else { throw CLIError.usage("Usage: aielements skill print | install --path DEST [--dry-run] [--json]") }
            let action = args.removeFirst()
            let content = try String(contentsOf: Catalog.resource("Skills/aielements-swiftui/SKILL.md"), encoding: .utf8)
            if action == "print" {
                try noExtra(args)
                return json ? try encode(SkillResult(content: content)) : content
            }
            guard action == "install" else { throw CLIError.usage("Unknown skill action '\(action)'. Use print or install.") }
            let options = try Options(args, values: ["--path"], flags: ["--dry-run"])
            return try materialize([GeneratedFile(path: "SKILL.md", content: content)], path: options.required("--path"), in: directory, dryRun: options.flags.contains("--dry-run"), json: json)
        default:
            throw CLIError.usage("Unknown command '\(command)'. Run aielements help.")
        }
    }

    public static func errorOutput(_ error: Error, json: Bool) -> String {
        let code = (error as? CLIError)?.exitCode ?? 1
        let message = (error as? CLIError)?.description ?? error.localizedDescription
        if json, let data = try? JSONEncoder().encode(ErrorResult(exitCode: code, message: message)), let text = String(data: data, encoding: .utf8) { return text }
        return "aielements: \(message)"
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    private func noExtra(_ args: [String]) throws {
        guard args.isEmpty else { throw CLIError.usage("Unexpected arguments: \(args.joined(separator: " "))") }
    }
    private func resolve(_ path: String, in directory: URL) -> URL {
        let base = URL(fileURLWithPath: directory.path, isDirectory: true)
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: base).standardizedFileURL
    }
    private func swiftLiteral(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\t", with: "\\t") + "\""
    }

    private func materialize(_ files: [GeneratedFile], path: String, in directory: URL, dryRun: Bool, json: Bool) throws -> String {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CLIError.usage("--path cannot be empty.") }
        let destination = resolve(path, in: directory)
        let fm = FileManager.default
        // Also reject broken symlinks: fileExists alone follows the link and misses them.
        guard !fm.fileExists(atPath: destination.path), (try? fm.destinationOfSymbolicLink(atPath: destination.path)) == nil else {
            throw CLIError.usage("Destination already exists: \(destination.path). Choose a new directory; existing files are never overwritten.")
        }
        if !dryRun {
            let parent = destination.deletingLastPathComponent()
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let staging = parent.appendingPathComponent(".aielements-\(UUID().uuidString)")
            try fm.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? fm.removeItem(at: staging) }
            for file in files {
                let url = staging.appendingPathComponent(file.path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(file.content.utf8).write(to: url, options: .withoutOverwriting)
            }
            try fm.moveItem(at: staging, to: destination)
        }
        let result = WriteResult(dryRun: dryRun, destination: destination.path, files: files)
        return json ? try encode(result) : "\(dryRun ? "Would create" : "Created") \(destination.path)\n" + files.map { "  \($0.path)" }.joined(separator: "\n")
    }

    private static func manifest(name: String, dependency: String) -> String {
        """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "\(name)",
            platforms: [.iOS(.v17), .macOS(.v14)],
            products: [.library(name: "\(name)", targets: ["\(name)"])],
            dependencies: [\(dependency)],
            targets: [.target(name: "\(name)", dependencies: [
                .product(name: "AIElements", package: "AIElements")
            ])]
        )

        """
    }

    public static let help = """
    aielements — native SwiftUI component tooling (macOS 14+, Swift 5.9+)
    Unofficial shadcn/ui AI Elements port. No model service or command execution.

    aielements list [--search TEXT] [--json]
    aielements show COMPONENT [--json]          Notes, source paths, complete example
    aielements example COMPONENT [--json]       Swift source on stdout
    aielements init --path NEW_DIR [--name AssistantUI]
                    [--local-package PATH | --revision COMMIT_SHA] [--dry-run] [--json]
    aielements skill print [--json]
    aielements skill install --path NEW_SKILL_DIR [--dry-run] [--json]
    aielements ui schema                       JSON Schema for documents and stream events
    aielements ui example [dashboard|bar-chart] Complete UI document JSON
    aielements ui stream                       Progressive dashboard events as JSONL
    aielements ui validate PATH [--json]        Validate .json or complete .jsonl stream
    aielements version [--json]
    aielements help [--json]

    COMPONENT accepts a slug (file-tree), a quoted name, or a Swift symbol (AIFileTree).
    init creates a reusable UI package for an existing app, not an Xcode app project.
    --path names the full NEW destination directory; existing paths are refused.
    --dry-run reports files without writing. Remote dependency defaults to branch main.
    JSON has schemaVersion: 1. Errors go to stderr; exit 2 = usage, 1 = I/O, 0 = success.
    """
}

private struct Options {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    init(_ args: [String], values allowed: Set<String>, flags allowedFlags: Set<String>) throws {
        var index = 0
        while index < args.count {
            let key = args[index]
            if allowedFlags.contains(key) {
                guard flags.insert(key).inserted else { throw CLIError.usage("Duplicate option \(key).") }
            } else if allowed.contains(key) {
                guard values[key] == nil, index + 1 < args.count, !args[index + 1].hasPrefix("--") else { throw CLIError.usage("Missing or duplicate value for \(key).") }
                index += 1; values[key] = args[index]
            } else { throw CLIError.usage("Unknown argument '\(key)'. Run aielements help.") }
            index += 1
        }
    }
    func required(_ key: String) throws -> String {
        guard let value = values[key] else { throw CLIError.usage("Missing required option \(key).") }
        return value
    }
}

private struct Version: Encodable { let schemaVersion = 1; let version: String }
private struct UIValidationResult: Encodable { let schemaVersion = 1; let valid: Bool; let revision: Int }
private struct HelpResult: Encodable { let schemaVersion = 1; let help: String }
private struct ListResult: Encodable { let schemaVersion = 1; let components: [Component] }
private struct ComponentResult: Encodable { let schemaVersion = 1; let component: Component; let code: String; let attribution: String }
private struct SkillResult: Encodable { let schemaVersion = 1; let content: String }
private struct GeneratedFile: Encodable { let path: String; let content: String }
private struct WriteResult: Encodable { let schemaVersion = 1; let dryRun: Bool; let destination: String; let files: [GeneratedFile] }
private struct ErrorResult: Encodable { let schemaVersion = 1; let exitCode: Int32; let message: String }
