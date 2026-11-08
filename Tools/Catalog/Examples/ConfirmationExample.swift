import SwiftUI
import AIElements

public struct ConfirmationExample: View {
    @State private var decision = AIConfirmationDecision.pending

    public init() {}

    public var body: some View {
        AIConfirmation("Apply the proposed changes?", description: "Demo only; no files are changed.", decision: $decision, executionStatus: .pending)
    }
}
