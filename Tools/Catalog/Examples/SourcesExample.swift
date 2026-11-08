import SwiftUI
import AIElements

public struct SourcesExample: View {


    public init() {}

    public var body: some View {
        AISources([
            .init(title: "shadcn/ui AI Elements", url: URL(string: "https://ui.shadcn.com/docs/ai-elements")!),
            .init(title: "SwiftUI port", url: URL(string: "https://github.com/elloray/AIElements")!)
        ], defaultOpen: true)
    }
}
