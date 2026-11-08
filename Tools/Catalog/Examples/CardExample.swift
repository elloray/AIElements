import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example card
@MainActor public struct CardExample: View {
    public init() {}

    public var body: some View {
        AICard("Report", description: "Monthly summary", footer: "Updated just now") {
            AITextLabel("1,234 visitors")
        }
    }
}
