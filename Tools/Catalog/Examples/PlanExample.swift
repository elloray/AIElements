import SwiftUI
import AIElements

public struct PlanExample: View {


    public init() {}

    public var body: some View {
        AIPlan("Add a chat screen", steps: [
            .init(id: "package", title: "Add the package", status: .completed),
            .init(id: "screen", title: "Build the screen", status: .running),
            .init(id: "verify", title: "Verify on both platforms", status: .pending)
        ])
    }
}
