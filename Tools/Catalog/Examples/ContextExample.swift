import SwiftUI
import AIElements

public struct ContextExample: View {


    public init() {}

    public var body: some View {
        AIContext(.init(input: 8420, output: 1260, reasoning: 980, limit: 128000))
    }
}
