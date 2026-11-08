import SwiftUI
import AIElements

public struct TestResultsExample: View {


    public init() {}

    public var body: some View {
        AITestResults(suites: [
            .init(id: "unit", name: "Unit tests", tests: [
                .init(id: "parse", name: "Parses messages", status: .passed),
                .init(id: "offline", name: "Handles offline mode", status: .failed, error: "Expected a retry action")
            ])
        ], command: "swift test")
    }
}
