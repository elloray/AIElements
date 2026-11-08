import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example select
@MainActor public struct SelectExample: View {
    @State private var selection = ""
    public init() {}

    public var body: some View {
        AISelect("Fruit", options: [.init("apple", label: "Apple"), .init("banana", label: "Banana")],
                 selection: $selection, placeholder: "Select a fruit")
    }
}
