import SwiftUI
import AIElements

public struct SubagentExample: View {


    public init() {}

    public var body: some View {
        AISubagent("research", status: .completed, result: "The package supports both platforms.") {
            AITrace { AITool("Read Package.swift", status: .completed, output: "iOS 17+, macOS 14+") }
        }
    }
}
