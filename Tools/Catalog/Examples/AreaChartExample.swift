import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example area-chart
@MainActor public struct AreaChartExample: View {
    @State private var selection = "Select a month"
    public init() {}

    public var body: some View {
        AICard("Area Chart", description: "January - March", style: .chart) {
            AIChart(.area, data: [
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
