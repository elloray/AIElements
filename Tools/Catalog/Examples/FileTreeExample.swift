import SwiftUI
import AIElements

public struct FileTreeExample: View {
    @State private var selection: String?
    @State private var expandedPaths: Set<String> = ["Sources"]

    public init() {}

    public var body: some View {
        AIFileTree([
            .init(path: "Sources", children: [.init(path: "Sources/App.swift")]),
            .init(path: "Package.swift")
        ], selection: $selection, expandedPaths: $expandedPaths)
    }
}
