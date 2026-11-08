import SwiftUI

public struct AIChartSeries: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public init(_ id: String, label: String) { self.id = id; self.label = label }
}
public struct AIChartRow: Identifiable, Hashable, Sendable {
    public var id: String { label }
    public var label: String
    public var values: [String: Double]
    public init(_ label: String, values: [String: Double]) { self.label = label; self.values = values }
}
public enum AIChartKind: String, Sendable { case bar, line, area }

/// Native chart marks, grid, compact axes and tooltip following shadcn's chart reference.
public struct AIChart: View {
    public var kind: AIChartKind
    public var data: [AIChartRow]
    public var series: [AIChartSeries]
    public var label: String
    public var showsLegend: Bool
    public var onSelect: ((AIChartRow) -> Void)?
    @Theme private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var selected: String?
    public init(_ kind: AIChartKind = .bar, data: [AIChartRow], series: [AIChartSeries], label: String = "Chart",
                showsLegend: Bool = false, onSelect: ((AIChartRow) -> Void)? = nil) {
        self.kind = kind; self.data = data; self.series = series; self.label = label
        self.showsLegend = showsLegend; self.onSelect = onSelect
    }
    private var colors: [Color] {
        // shadcn's chart scale is shared by light/dark; CSS Lab D50 chart-1 converted to sRGB.
        [Color(red: 0.557, green: 0.773, blue: 1),
         Color(red: 0.169, green: 0.498, blue: 1), Color(red: 0.082, green: 0.365, blue: 0.988),
         Color(red: 0.078, green: 0.278, blue: 0.902), Color(red: 0.118, green: 0.227, blue: 0.541)]
    }
    private var cleanData: [AIChartRow] {
        var seen = Set<String>()
        return Array(data.filter { seen.insert($0.label).inserted }.prefix(200))
    }
    public var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let rows = cleanData
                let metrics = ChartMetrics(rows: rows, series: series, size: proxy.size)
                Canvas { context, size in
                    for index in 0...4 {
                        let y = metrics.top + metrics.height * CGFloat(index) / 4
                        var path = Path(); path.move(to: CGPoint(x: 5, y: y)); path.addLine(to: CGPoint(x: size.width - 5, y: y))
                        context.stroke(path, with: .color(theme.border.opacity(0.5)), lineWidth: 1)
                    }
                    for (seriesIndex, series) in series.prefix(5).enumerated() {
                        let color = colors[seriesIndex % colors.count]
                        var line = Path()
                        var points: [CGPoint] = []
                        for (index, row) in rows.enumerated() {
                            guard let value = row.values[series.id], value.isFinite else { continue }
                            let x = metrics.x(index), y = metrics.y(value)
                            points.append(CGPoint(x: x, y: y))
                            if kind == .bar {
                                let count = CGFloat(max(1, min(5, self.series.count)))
                                let width = max(1, (metrics.band * 0.8 - (count - 1) * 4) / count)
                                let left = x - metrics.band * 0.4 + CGFloat(seriesIndex) * (width + 4)
                                let zero = metrics.y(0)
                                let rect = CGRect(x: left, y: min(y, zero), width: width, height: abs(zero - y))
                                context.fill(Path(roundedRect: rect, cornerRadius: min(8, width / 2, rect.height / 2)), with: .color(color))
                            }
                        }
                        if kind != .bar, let first = points.first {
                            line.move(to: first)
                            for point in points.dropFirst() { line.addLine(to: point) }
                            if kind == .area, let last = points.last {
                                var area = line; area.addLine(to: CGPoint(x: last.x, y: metrics.y(0)))
                                area.addLine(to: CGPoint(x: first.x, y: metrics.y(0))); area.closeSubpath()
                                context.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(0.4), color.opacity(0.05)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
                            }
                            context.stroke(line, with: .color(color), lineWidth: 2)
                            if points.count == 1 { context.fill(Path(ellipseIn: CGRect(x: first.x - 3, y: first.y - 3, width: 6, height: 6)), with: .color(color)) }
                        }
                    }
                    let stride = max(1, Int(ceil(CGFloat(rows.count) * 34 / max(1, size.width))))
                    for index in rows.indices where index % stride == 0 {
                        context.draw(Text(String(rows[index].label.prefix(3))).font(AITypography.font(12)).foregroundColor(theme.mutedForeground),
                                     at: CGPoint(x: metrics.x(index), y: metrics.top + metrics.height + 20))
                    }
                }.contentShape(Rectangle())
                    .onTapGesture { point in select(at: point.x, metrics: metrics, rows: rows, emit: true) }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point): select(at: point.x, metrics: metrics, rows: rows, emit: false)
                        case .ended: selected = nil
                        }
                    }
                if rows.isEmpty {
                    Text("No data yet").aiFont(12).foregroundStyle(theme.mutedForeground).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let selected, let row = rows.first(where: { $0.label == selected }) {
                    tooltip(row).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).allowsHitTesting(false)
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel(label)
                .accessibilityValue(accessibleValue)
                .accessibilityAdjustableAction { direction in
                    let rows = cleanData
                    guard !rows.isEmpty else { return }
                    let old = rows.firstIndex { $0.label == selected } ?? -1
                    let index = max(0, min(rows.count - 1, old + (direction == .increment ? 1 : -1)))
                    selected = rows[index].label; onSelect?(rows[index])
                }
            if showsLegend {
                HStack(spacing: 12) {
                    ForEach(Array(series.prefix(5).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(colors[index % colors.count]).frame(width: 8, height: 8)
                            Text(item.label).aiFont(12)
                        }
                    }
                }
            }
        }
    }
    private var accessibleValue: String {
        let rows = cleanData
        guard let row = rows.first(where: { $0.label == selected }) ?? rows.first else { return "No data yet" }
        return "\(row.label). " + series.map { "\($0.label): \((row.values[$0.id] ?? 0).formatted())" }.joined(separator: ", ")
    }
    private func select(at x: CGFloat, metrics: ChartMetrics, rows: [AIChartRow], emit: Bool) {
        guard !rows.isEmpty else { return }
        let index = min(rows.count - 1, max(0, Int((x - 5) / metrics.band)))
        selected = rows[index].label
        if emit { onSelect?(rows[index]) }
    }
    private func tooltip(_ row: AIChartRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.label).aiFont(12, weight: .medium)
            ForEach(Array(series.prefix(5).enumerated()), id: \.element.id) { index, series in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(colors[index % colors.count]).frame(width: 10, height: 10)
                    Text(series.label).foregroundStyle(theme.mutedForeground)
                    Text((row.values[series.id] ?? 0).formatted()).monospacedDigit()
                }.aiFont(12)
            }
        }.padding(10).foregroundStyle(theme.foreground).background(theme.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.border, lineWidth: 1))
    }
}

private struct ChartMetrics {
    var minimum: Double
    var maximum: Double
    var band: CGFloat
    var height: CGFloat
    let top: CGFloat = 5
    init(rows: [AIChartRow], series: [AIChartSeries], size: CGSize) {
        let values = rows.flatMap { row in series.compactMap { row.values[$0.id] }.filter { $0.isFinite && abs($0) <= 1e15 } }
        let low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 1)
        let range = max(1, high - low)
        let power = pow(10, floor(log10(range / 4)))
        let step = ceil(range / 4 / power) * power
        minimum = floor(low / step) * step; maximum = max(minimum + step, ceil(high / step) * step)
        band = max(1, size.width - 10) / CGFloat(max(1, rows.count))
        height = max(1, size.height.rounded() - 40)
    }
    func x(_ index: Int) -> CGFloat { 5 + band * (CGFloat(index) + 0.5) }
    func y(_ value: Double) -> CGFloat { top + height * (1 - min(1, max(0, (value - minimum) / (maximum - minimum)))) }
}
