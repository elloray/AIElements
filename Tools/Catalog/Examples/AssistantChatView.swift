import SwiftUI
import AIElements

/// Local UI demo. Connect your own service where the host accepts the submission.
public struct AssistantChatView: View {
    @State private var draft = ""
    @State private var messages: [AIChatMessage] = []
    @State private var submissionRevision = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            AIChat(messages: messages)
            AIPromptInput(text: $draft, attachmentResetID: submissionRevision) { submission in
                messages.append(.init(
                    role: .user,
                    text: submission.text,
                    parts: submission.attachments.map { .attachment($0) }
                ))
                // Accepted locally. For a real service, preserve the draft on failure.
                draft = ""
                submissionRevision += 1
            }
        }
        .padding()
        // Keep the platform default density: iOS uses 44 pt touch targets.
    }
}
