import SwiftUI
import AIElements

public struct ChainOfThoughtExample: View {


    public init() {}

    public var body: some View {
        AIChainOfThought(steps: [
            .init(id: "read", title: "Read Package.swift", status: .completed, content: .code("swift-tools-version: 5.9")),
            .init(id: "check", title: "Checking dependencies", status: .running)
        ])
    }
}
