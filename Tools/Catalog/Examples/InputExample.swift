import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example input
@MainActor public struct InputExample: View {
    @State private var text = ""
    public init() {}

    public var body: some View {
        AIInput("Report name", text: $text, placeholder: "Name your report")
    }
}
