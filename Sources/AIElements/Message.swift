import SwiftUI

public struct AIMessage<Content: View>: View {
    public var role: AIMessageRole
    private let content: Content
    private var footer: AnyView?
    private var footerSpacing: CGFloat = 8
    @Theme private var theme
    public init(role: AIMessageRole, @ViewBuilder content: () -> Content) { self.role = role; self.content = content(); self.footer = nil }
    public init<Footer: View>(role: AIMessageRole, footerSpacing: CGFloat = 8, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.role = role; self.content = content(); self.footer = AnyView(footer()); self.footerSpacing = footerSpacing
    }
    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if role == .user { Spacer(minLength: 0) }
            VStack(alignment: role == .user ? .trailing : .leading, spacing: footerSpacing) {
                VStack(alignment: .leading, spacing: 12) { content }.fixedSize(horizontal: false, vertical: true)
                    .aiFont().foregroundStyle(role == .system ? theme.mutedForeground : theme.foreground)
                    .environment(\.aiParagraphMuted, role == .system)
                    // Include the reference bubble's 1 pt transparent border in its layout.
                    .padding(.horizontal, role == .user ? 13 : 0).padding(.vertical, role == .user ? 11 : 0)
                    .background(role == .user ? theme.muted : .clear, in: RoundedRectangle(cornerRadius: 22))
                if let footer { footer }
            }.layoutPriority(1)
            if role != .user { Spacer(minLength: 0) }
        }.frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
            .modifier(AIMessageWidth(role: role))
            .accessibilityElement(children: .contain).accessibilityLabel(role.rawValue.capitalized)
    }
}
/// Plain message text with browser-style word wrapping and the reference line height.
/// Use inside a user-role `AIMessage`; short messages keep their natural bubble width.
public struct AIMessageText: View {
    public var text: String
    public init(_ text: String) { self.text = text }
    public var body: some View { NativeTextParagraph(message: text) }
}

// A layout proposal keeps the bubble at 80% without a GeometryReader height dependency.
private struct AIMessageWidth: ViewModifier {
    var role: AIMessageRole
    func body(content: Content) -> some View { if role == .user { AIAlignedWidthLayout(fraction: 0.8) { content } } else { content } }
}
private struct AIAlignedWidthLayout: Layout {
    var fraction: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 384
        return CGSize(width: width, height: subviews[0].sizeThatFits(.init(width: width * fraction, height: nil)).height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: CGPoint(x: bounds.maxX, y: bounds.minY), anchor: .topTrailing, proposal: .init(width: bounds.width * fraction, height: nil))
    }
}
public struct AIMessageActions: View {
    public var text: String
    public var onRetry: (() -> Void)?
    public var onEdit: (() -> Void)?
    public var onFeedback: ((Bool) -> Void)?
    public var onFeedbackChange: ((Bool?) -> Void)?
    private var externalFeedback: Binding<Bool?>?
    @Environment(\.aiControlDensity) private var density
    @State private var localFeedback: Bool?
    @Theme private var theme
    public init(text: String, onRetry: (() -> Void)? = nil, onEdit: (() -> Void)? = nil, feedback: Binding<Bool?>? = nil, onFeedbackChange: ((Bool?) -> Void)? = nil, onFeedback: ((Bool) -> Void)? = nil) {
        self.text = text; self.onRetry = onRetry; self.onEdit = onEdit; self.externalFeedback = feedback; self.onFeedbackChange = onFeedbackChange; self.onFeedback = onFeedback
    }
    private var feedback: Bool? { externalFeedback?.wrappedValue ?? localFeedback }
    public var body: some View {
        HStack(spacing: density == .comfortable ? 0 : 4) {
            if !text.isEmpty { AICopyButton(text) }
            if let onEdit { Button(action: onEdit) { AIIcon(.pencil, size: 16).foregroundStyle(theme.mutedForeground) }.buttonStyle(AIButtonStyle(.ghost, size: .iconSmall)).accessibilityLabel("Edit message").help("Edit message") }
            if onFeedback != nil || onFeedbackChange != nil || externalFeedback != nil { feedbackButton(true); feedbackButton(false) }
            if let onRetry { Button(action: onRetry) { AIIcon(.rotateCcw, size: 16).foregroundStyle(theme.mutedForeground) }.buttonStyle(AIButtonStyle(.ghost, size: .iconSmall)).accessibilityLabel("Retry response").help("Retry response") }
        }.foregroundStyle(theme.mutedForeground)
    }
    private func feedbackButton(_ positive: Bool) -> some View {
        Button {
            let value: Bool? = feedback == positive ? nil : positive
            if let externalFeedback { externalFeedback.wrappedValue = value } else { localFeedback = value }
            onFeedbackChange?(value); if let value { onFeedback?(value) }
        } label: { AIIcon(positive ? .thumbsUp : .thumbsDown, size: 16).foregroundStyle(feedback == positive ? theme.foreground : theme.mutedForeground) }
            .buttonStyle(AIButtonStyle(.ghost, size: .iconSmall)).accessibilityLabel(positive ? "Good response" : "Bad response")
            .accessibilityAddTraits(feedback == positive ? .isSelected : []).accessibilityValue(feedback == positive ? "Selected" : "Not selected")
            .help(positive ? "Good response" : "Bad response")
    }
}

private struct ScrollMetrics: Equatable { var bottom: CGFloat = 0; var height: CGFloat = 0 }
private struct BottomPositionKey: PreferenceKey {
    static var defaultValue = ScrollMetrics()
    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) { value = nextValue() }
}
/// Follows streaming content while at the live edge. A new scrollAnchor starts a user turn.
public struct AIConversation<Content: View>: View {
    public var revision: AnyHashable
    public var scrollAnchor: AnyHashable?
    public var isStreaming: Bool
    public var initialScrollToBottom: Bool
    private var contentInset: CGFloat
    @State private var positioned = false
    private let content: Content
    @State private var following = true
    @State private var previous = ScrollMetrics()
    @State private var lastAnchor: AnyHashable?
    @Namespace private var coordinate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(revision: AnyHashable, scrollAnchor: AnyHashable? = nil, isStreaming: Bool = false, initialScrollToBottom: Bool = true, contentInset: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.revision = revision; self.scrollAnchor = scrollAnchor; self.isStreaming = isStreaming; self.initialScrollToBottom = initialScrollToBottom; self.contentInset = contentInset; self.content = content()
    }
    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { content; Color.clear.frame(height: 1).id("ai-bottom") }
                        .padding(contentInset)
                        .background(GeometryReader { geo in Color.clear.preference(key: BottomPositionKey.self, value: ScrollMetrics(bottom: geo.frame(in: .named(coordinate)).maxY, height: geo.size.height)) })
                }.coordinateSpace(name: coordinate)
                    .onPreferenceChange(BottomPositionKey.self) { metrics in
                        // Growing content is not a user's scroll-away gesture.
                        if abs(metrics.height - previous.height) < 0.5 { following = metrics.bottom <= geometry.size.height + 56 }
                        previous = metrics
                    }
                    .task(id: revision) {
                        await Task.yield()
                        if !positioned { positioned = true; if !initialScrollToBottom && scrollAnchor == nil { return } }
                        if let anchor = scrollAnchor, anchor != lastAnchor { lastAnchor = anchor; following = true; proxy.scrollTo(anchor, anchor: .top) }
                        else if following { proxy.scrollTo("ai-bottom", anchor: .bottom) }
                    }
                    .overlay(alignment: .bottom) {
                        if !following {
                            Button { following = true; withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("ai-bottom", anchor: .bottom) } }
                            label: { AIIcon(.arrowDown) }.buttonStyle(AIButtonStyle(.outline, size: .icon)).padding(12).accessibilityLabel("Jump to latest message").help("Jump to latest message")
                        }
                    }
            }
        }
    }
}
public struct AIChat: View {
    @Environment(\.aiControlDensity) private var density
    @ScaledMetric(relativeTo: .body) private var emptyTextWidth: CGFloat = 206
    @ScaledMetric(relativeTo: .body) private var emptyDescriptionOffset: CGFloat = 3
    @Theme private var theme
    public var messages: [AIChatMessage]
    public var isStreaming: Bool
    public var onEdit: ((AIChatMessage) -> Void)?
    public var onRetry: ((AIChatMessage) -> Void)?
    /// The host replaces the approval part with its updated tool state after accepting the decision.
    public var onToolApproval: ((String, AIConfirmationDecision) async throws -> Void)?
    public var messageContent: ((AIChatMessage) -> AnyView)?
    public init(messages: [AIChatMessage], isStreaming: Bool = false, onEdit: ((AIChatMessage) -> Void)? = nil, onRetry: ((AIChatMessage) -> Void)? = nil, onToolApproval: ((String, AIConfirmationDecision) async throws -> Void)? = nil, messageContent: ((AIChatMessage) -> AnyView)? = nil) {
        self.messages = messages; self.isStreaming = isStreaming; self.onEdit = onEdit; self.onRetry = onRetry; self.messageContent = messageContent; self.onToolApproval = onToolApproval
    }
    public var body: some View {
        GeometryReader { viewport in
            let latest = messages.lastIndex { $0.role == .user } ?? messages.startIndex
            let anchor = messages.indices.contains(latest) ? messages[latest].id : nil
            AIConversation(revision: ChatRevision(last: messages.last, count: messages.count, streaming: isStreaming), scrollAnchor: anchor, isStreaming: isStreaming) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if messages.isEmpty {
                        VStack(spacing: 8) {
                            AIIcon(.messageCircleDashed, size: 20).frame(width: 40, height: 40)
                                .background(theme.muted, in: RoundedRectangle(cornerRadius: 12)).padding(.bottom, 8)
                            AITextLabel("What should we build?", size: 18, weight: .medium, tracking: -0.45).frame(minHeight: 28)
                            NativeTextParagraph(markdown: "The agent can read your code, run commands and make changes. Press send to start.")
                                .environment(\.aiParagraphMuted, true).environment(\.aiParagraphLineHeight, 22.75)
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: emptyTextWidth)
                                // Align glyphs to the reference without moving the icon or title.
                                .offset(y: -emptyDescriptionOffset)
                        }.foregroundStyle(theme.foreground).frame(maxWidth: 320).padding(.horizontal, 32)
                            .frame(maxWidth: .infinity, minHeight: max(0, viewport.size.height - 32))
                    } else {
                        ForEach(Array(messages[..<latest])) { message in messageView(message) }
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(Array(messages[latest...])) { message in messageView(message) }
                            if isStreaming && messages.last?.text.isEmpty != false && messages.last?.parts.isEmpty != false { AITraceLine("Responding", icon: .circleDot, status: .running) }
                        }.frame(maxWidth: .infinity, minHeight: max(0, viewport.size.height - 32), alignment: .topLeading).id(anchor ?? "")
                    }
                }
            }
        }
    }
    @ViewBuilder private func messageView(_ message: AIChatMessage) -> some View {
        if let messageContent { messageContent(message) }
        else {
            AIMessage(role: message.role, footerSpacing: density == .comfortable ? 0 : 8) {
                if !message.text.isEmpty {
                    if message.role == .user { AIMessageText(message.text) } else { AIMessageResponse(message.text) }
                }
                ForEach(Array(message.parts.enumerated()), id: \.offset) { _, part in
                    if message.role == .user, case .text(let text) = part { AIMessageText(text) } else { partView(part) }
                }
            } footer: {
                if !(isStreaming && message.id == messages.last?.id) {
                    AIMessageActions(text: message.copyableText, onRetry: message.role == .assistant ? onRetry.map { action in { action(message) } } : nil,
                                     onEdit: message.role == .user ? onEdit.map { action in { action(message) } } : nil)
                }
            }
        }
    }
    @ViewBuilder private func partView(_ part: AIMessagePart) -> some View {
        switch part {
        case .text(let text): AIMessageResponse(text)
        case .reasoning(let text, let streaming, let duration): AIReasoning(text, isStreaming: streaming, duration: duration)
        case .tool(let name, let status, let input, let output): AITool(name, status: status, input: input, output: output)
        case .toolApproval(let id, let name, let input):
            ChatToolApproval(requestID: id, name: name, input: input, submit: onToolApproval).id(id)
        case .attachment(let attachment): AIAttachmentView(attachment)
        case .sources(let sources): AISources(sources)
        }
    }
}
private struct ChatRevision: Hashable { var last: AIChatMessage?; var count: Int; var streaming: Bool }

private struct ChatToolApproval: View {
    var requestID: String
    var name: String
    var input: String?
    var submit: ((String, AIConfirmationDecision) async throws -> Void)?
    @State private var decision = AIConfirmationDecision.pending

    var body: some View {
        AIConfirmation("Run \(name)?", description: input, decision: $decision, executionStatus: .pending,
                       toolName: name, submitDecision: submit.map { callback in
            { value in try await callback(requestID, value) }
        }).disabled(submit == nil)
    }
}
