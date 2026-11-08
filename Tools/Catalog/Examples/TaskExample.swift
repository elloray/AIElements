import SwiftUI
import AIElements

public struct TaskExample: View {


    public init() {}

    public var body: some View {
        AITask("Inspect the project", steps: [
            .init(id: "read", title: "Read Package.swift", status: .completed),
            .init(id: "tests", title: "Inspect tests", status: .running)
        ])
    }
}
