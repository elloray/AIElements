import SwiftUI
import AIElements

public struct PromptInputExample: View {
    @State private var text = ""
    @State private var resetID = 0
    @State private var lastSubmission = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading) {
            AIPromptInput(text: $text, attachmentResetID: resetID) { submission in
                // This demo accepts locally. A network host should clear only on acceptance.
                lastSubmission = submission.text
                text = ""
                resetID += 1
            }
            Text(lastSubmission)
        }
    }
}
