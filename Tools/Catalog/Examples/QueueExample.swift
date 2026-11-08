import SwiftUI
import AIElements

public struct QueueExample: View {


    public init() {}

    public var body: some View {
        AIQueue(items: [
            .init(id: "inspect", title: "Inspect files", status: .completed),
            .init(id: "implement", title: "Implement the change", status: .running),
            .init(id: "test", title: "Run tests", status: .pending)
        ])
    }
}
