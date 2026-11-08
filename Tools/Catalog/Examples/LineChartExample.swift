import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example line-chart
@MainActor public struct LineChartExample: View {
    @State private var selection = "Select a month"
    public init() {}

    public var body: some View {
        AICard("Line Chart", description: "January - March", style: .chart) {
            AIChart(.line, data: [
                .init("January", values: ["desktop": 186]),
                .init("February", values: ["desktop": 305]),
                .init("March", values: ["desktop": 237])
            ], series: [.init("desktop", label: "Desktop")], label: "Monthly visitors") { row in
                selection = row.label
            }
            .frame(height: 180)
            AITextLabel(selection)
        }
    }
}
