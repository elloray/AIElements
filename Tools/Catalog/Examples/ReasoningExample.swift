import SwiftUI
import AIElements

public struct ReasoningExample: View {


    public init() {}

    public var body: some View {
        AIReasoning("Checking the package dependencies and supported platforms.", isStreaming: false, duration: 2)
    }
}
