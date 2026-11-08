import SwiftUI
import AIElements

public struct SuggestionExample: View {
    @State private var selected = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading) {
            AISuggestions(["Explain this code", "Write tests"]) { selected = $0 }
            Text(selected)
        }
    }
}
