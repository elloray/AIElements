import SwiftUI
import AIElements

public struct ToolExample: View {


    public init() {}

    public var body: some View {
        AITool("Read Package.swift", status: .completed, input: "Package.swift", output: "Library target: AIElements")
    }
}
