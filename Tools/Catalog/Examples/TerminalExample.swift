import SwiftUI
import AIElements

public struct TerminalExample: View {


    public init() {}

    public var body: some View {
        AITerminal(command: "swift test", output: "All tests passed. (Example output)", status: .completed, exitCode: 0)
    }
}
