import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example button
@MainActor public struct ButtonExample: View {
    @State private var status = "Ready"
    public init() {}

    public var body: some View {
        VStack {
            Button("Save report") { status = "Save requested" }
                .buttonStyle(AIFoundationButtonStyle(.primary))
            AITextLabel(status)
        }
    }
}
