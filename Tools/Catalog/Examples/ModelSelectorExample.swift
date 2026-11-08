import SwiftUI
import AIElements

public struct ModelSelectorExample: View {
    @State private var model = "demo-model"
    @State private var effort = AIEffort.medium

    public init() {}

    public var body: some View {
        AIModelSelector(models: [
            .init(id: "demo-model", name: "Demo model", provider: "Your service")
        ], selection: $model, effort: $effort)
    }
}
