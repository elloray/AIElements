import Foundation
import XCTest
@testable import AIElementsUIProtocol

final class ProtocolTests: XCTestCase {
    func testBundledStreamShowsPartialDataAndPreservesDraft() throws {
        var session = AIUISession(); var decoder = AIUIStreamDecoder()
        var partialCounts: [Int] = []
        var edited = false
        for byte in try AIUIResources.data(named: "dashboard-stream") {
            try decoder.append(Data([byte])) { frame in
                try session.apply(frame)
                if session.document?.nodes["name"] != nil && !edited {
                    try session.setValue(.string("Edited during generation"), nodeID: "name"); edited = true
                }
                if let count = session.document?.nodes["chart"]?.props?["data"]?.array?.count { partialCounts.append(count) }
            }
        }
        XCTAssertEqual(session.phase, .complete)
        XCTAssertTrue(partialCounts.contains(1)); XCTAssertTrue(partialCounts.contains(6))
        XCTAssertEqual(session.document?.state["reportName"], .string("Edited during generation"))
    }
    func testExamplesValidateAndRoundTrip() throws {
        for name in ["dashboard", "bar-chart"] {
            let doc = try AIUIDocument.decode(AIUIResources.data(named: name))
            XCTAssertEqual(try AIUIDocument.decode(JSONEncoder().encode(doc)), doc)
        }
    }
    func testEveryPossibleByteSplitIncludingUnicode() throws {
        let event = AIUIStreamEvent(.begin, surfaceID: "中文🙂", revision: 0, root: "root")
        let data = try JSONEncoder().encode(event) + Data([10])
        for index in 0...data.count {
            var decoder = AIUIStreamDecoder()
            let first = try decoder.append(data.prefix(index))
            let second = try decoder.append(data.dropFirst(index))
            XCTAssertEqual(first + second, [event])
            XCTAssertEqual(try decoder.finish(), [])
        }
    }
    func testProgressiveRenderingBeforeCompletionAndStableUserInput() throws {
        var session = AIUISession()
        try session.apply(.init(.begin, surfaceID: "demo", revision: 0, root: "root"))
        XCTAssertEqual(session.phase, .streaming)
        try session.apply(.init(.update, surfaceID: "demo", revision: 1, baseRevision: 0,
                                nodes: ["root": .init("Card", props: ["title": .string("Report")], children: ["field", "chart"])]))
        XCTAssertEqual(session.document?.nodes["root"]?.props?["title"], .string("Report"))
        try session.apply(.init(.update, surfaceID: "demo", revision: 2, baseRevision: 1,
                                nodes: ["field": .init("Input", props: ["label": .string("Title")], bindings: ["value": "draft"])], state: ["draft": .string("")]))
        try session.setValue(.string("User draft"), nodeID: "field")
        let chart = try AIUIDocument.decode(AIUIResources.data(named: "bar-chart")).nodes["chart"]!
        try session.apply(.init(.update, surfaceID: "demo", revision: 3, baseRevision: 2, nodes: ["chart": chart]))
        XCTAssertEqual(session.document?.state["draft"], .string("User draft"))
        try session.apply(.init(.complete, surfaceID: "demo", revision: 4, baseRevision: 3))
        XCTAssertEqual(session.phase, .complete)
    }
    func testBadPatchIsAtomicAndOutOfOrderEventsAreRejected() throws {
        var session = try AIUISession(document: AIUIDocument.decode(AIUIResources.data(named: "dashboard")))
        let old = session.document
        XCTAssertThrowsError(try session.apply(.init(.update, surfaceID: "report", revision: 1, baseRevision: 0,
                                                    nodes: ["bad": .init("ExecuteShell")], state: ["reportName": .string("bad")])))
        XCTAssertEqual(session.document, old)
        XCTAssertThrowsError(try session.apply(.init(.update, surfaceID: "report", revision: 3, baseRevision: 0)))
        XCTAssertThrowsError(try session.apply(.init(.update, surfaceID: "other", revision: 1, baseRevision: 0)))
        XCTAssertEqual(session.document, old)
    }
    func testCompleteRequiresReferencesAndBindingsToResolve() throws {
        var session = AIUISession()
        try session.apply(.init(.begin, surfaceID: "test", revision: 0, root: "missing"))
        XCTAssertThrowsError(try session.apply(.init(.complete, surfaceID: "test", revision: 1, baseRevision: 0)))
        XCTAssertEqual(session.document?.revision, 0)
        session.interrupt()
        XCTAssertEqual(session.phase, .failed)
        XCTAssertNotNil(session.document)
    }
    func testCyclesMultipleParentsAndValueLimits() throws {
        let cycle = AIUIDocument(id: "test", root: "a", nodes: ["a": .init("Stack", children: ["b"]), "b": .init("Stack", children: ["a"])])
        XCTAssertThrowsError(try cycle.validate(allowIncomplete: true))
        let sharing = AIUIDocument(id: "test", root: "a", nodes: ["a": .init("Stack", children: ["b", "c"]), "b": .init("Stack", children: ["c"]), "c": .init("Text")])
        XCTAssertThrowsError(try sharing.validate())
        let huge = AIUIDocument(id: "test", root: "a", nodes: ["a": .init("Progress", props: ["value": .number(.infinity)])])
        XCTAssertThrowsError(try huge.validate())
    }
    func testActionOnlyExportsNamedStateAndNeverExecutes() throws {
        var session = try AIUISession(document: AIUIDocument.decode(AIUIResources.data(named: "dashboard")))
        try session.setValue(.string("My report"), nodeID: "name")
        let event = try XCTUnwrap(session.event(nodeID: "submit", event: "press"))
        XCTAssertEqual(event.name, "save_report")
        XCTAssertEqual(event.state["reportName"], .string("My report"))
        XCTAssertEqual(event.state.count, 3)
        XCTAssertNil(session.event(nodeID: "chart", event: "press"))
    }
    func testValidPrefixIsDeliveredBeforeMalformedLine() throws {
        var decoder = AIUIStreamDecoder()
        let event = AIUIStreamEvent(.begin, surfaceID: "demo", revision: 0, root: "root")
        let bytes = try JSONEncoder().encode(event) + Data("\n{bad}\n".utf8)
        var received: [AIUIStreamEvent] = []
        XCTAssertThrowsError(try decoder.append(bytes) { received.append($0) })
        XCTAssertEqual(received, [event])
    }
    func testTruncationAndSizeLimits() throws {
        var session = AIUISession()
        XCTAssertThrowsError(try session.apply(.init(.begin, surfaceID: "bad", revision: .max, root: "root")))
        var decoder = AIUIStreamDecoder(maximumLineBytes: 10)
        XCTAssertThrowsError(try decoder.append(Data(repeating: 32, count: 11)))
        decoder.reset()
        _ = try decoder.append(Data("{\"version\"".utf8))
        XCTAssertThrowsError(try decoder.finish())
    }
}
