import SwiftUI
import AIElements

public struct InlineCitationExample: View {


    public init() {}

    public var body: some View {
        AICitedText([
            .text("This library is inspired by "),
            .source(.init(title: "shadcn/ui AI Elements", url: URL(string: "https://ui.shadcn.com/docs/ai-elements")!)),
            .text(" and implemented in native SwiftUI.")
        ])
    }
}
