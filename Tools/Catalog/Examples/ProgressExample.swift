import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example progress
@MainActor public struct ProgressExample: View {
    public init() {}

    public var body: some View {
        AIProgress(value: 66, total: 100, label: "Generating report")
    }
}
