import SwiftUI
import AIElements

public struct MessageExample: View {


    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIMessage(role: .user) { AIMessageText("How do I install the library?") }
            AIMessage(role: .assistant) {
                AIMessageResponse("Add **AIElements** with Swift Package Manager.")
            } footer: {
                AIMessageActions(text: "Add AIElements with Swift Package Manager.")
            }
        }
    }
}
