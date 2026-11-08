import Foundation
import XCTest
@testable import AIElementsCLIKit

final class CLIKitTests: XCTestCase {
    private let cli = CLI()

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func object(_ text: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    func testEveryCatalogEntryHasAnExampleAndUniqueIdentity() throws {
        let catalog = try Catalog.bundled()
        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertEqual(catalog.components.count, 21)
        XCTAssertEqual(Set(catalog.components.map(\.id)).count, 21)
        XCTAssertEqual(Set(catalog.components.map(\.exampleFile)).count, 21)
        for component in catalog.components {
            XCTAssertFalse(try catalog.example(component).isEmpty)
            XCTAssertEqual(try catalog.component(component.symbols[0]).id, component.id)
        }
    }

    func testSearchFindsChineseAndSwiftNames() throws {
        for query in ["AIFileTree", "文件树", "file-tree"] {
            let output = try object(cli.run(["list", "--search", query, "--json"]))
            let items = try XCTUnwrap(output["components"] as? [[String: Any]])
            XCTAssertEqual(items.map { $0["id"] as? String }, ["file-tree"])
        }
        let output = try object(cli.run(["list", "--search", "no such component", "--json"]))
        XCTAssertEqual((output["components"] as? [Any])?.count, 0)
    }

    func testJSONAndRawSourceAgree() throws {
        let output = try object(cli.run(["show", "AIChat", "--json"]))
        XCTAssertEqual(output["schemaVersion"] as? Int, 1)
        XCTAssertEqual(output["code"] as? String, try cli.run(["example", "chat"]))
        let help = try object(cli.run(["help", "--json"]))
        XCTAssertEqual(help["schemaVersion"] as? Int, 1)
    }

    func testBadArgumentsFailInsteadOfSilentlyWriting() throws {
        let root = try temporaryDirectory()
        let cases = [
            ["show", "nonexistent"], ["example", "../../secret"],
            ["init"], ["init", "--path", "New", "--name", "../Escape"],
            ["init", "--path", "New", "--name", "SwiftUI"],
            ["init", "--path", "New", "--revision", "main"],
            ["init", "--path", "New", "--force"],
            ["init", "--path", "New", "--local-package", ".", "--revision", String(repeating: "a", count: 40)],
            ["init", "--path", "New", "--path", "Elsewhere"],
            ["skill", "install"], ["skill", "erase"], ["unknown"]
        ]
        for args in cases {
            XCTAssertThrowsError(try cli.run(args, directory: root)) { error in
                XCTAssertEqual((error as? CLIError)?.exitCode, 2)
            }
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testDryRunCreatesNothingAndReportsExactFutureContents() throws {
        let root = try temporaryDirectory()
        let args = ["init", "--path", "nested/Feature", "--name", "Feature", "--json"]
        let preview = try object(cli.run(args + ["--dry-run"], directory: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("nested").path))
        let files = try XCTUnwrap(preview["files"] as? [[String: String]])
        _ = try cli.run(args, directory: root)
        for file in files {
            let url = root.appendingPathComponent("nested/Feature").appendingPathComponent(try XCTUnwrap(file["path"]))
            XCTAssertEqual(try String(contentsOf: url), file["content"])
        }
    }

    func testExistingDirectoriesAndDanglingSymlinksAreNeverOverwritten() throws {
        let root = try temporaryDirectory()
        let existing = root.appendingPathComponent("existing")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: false)
        let marker = existing.appendingPathComponent("keep.txt")
        try "user content".write(to: marker, atomically: true, encoding: .utf8)
        for command in [["init", "--path", "existing"], ["skill", "install", "--path", "existing"]] {
            XCTAssertThrowsError(try cli.run(command, directory: root))
        }
        XCTAssertEqual(try String(contentsOf: marker), "user content")
        let dangling = root.appendingPathComponent("dangling")
        try FileManager.default.createSymbolicLink(atPath: dangling.path, withDestinationPath: "missing")
        XCTAssertThrowsError(try cli.run(["init", "--path", "dangling"], directory: root))
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: dangling.path), "missing")
    }

    func testSkillInstallationMatchesPrintedContentAndRefusesReinstall() throws {
        let root = try temporaryDirectory()
        let args = ["skill", "install", "--path", ".agents/skills/aielements-swiftui"]
        _ = try cli.run(args + ["--dry-run"], directory: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".agents").path))
        _ = try cli.run(args, directory: root)
        let installed = root.appendingPathComponent(".agents/skills/aielements-swiftui/SKILL.md")
        XCTAssertEqual(try String(contentsOf: installed), try cli.run(["skill", "print"]))
        XCTAssertThrowsError(try cli.run(args, directory: root))
    }

    func testErrorsAreMachineReadable() throws {
        let output = CLI.errorOutput(CLIError.usage("Unknown component"), json: true)
        let value = try object(output)
        XCTAssertEqual(value["schemaVersion"] as? Int, 1)
        XCTAssertEqual(value["exitCode"] as? Int, 2)
        XCTAssertEqual(value["message"] as? String, "Unknown component")
    }
}
