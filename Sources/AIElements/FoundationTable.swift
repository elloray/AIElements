import SwiftUI

public struct AITableColumn: Identifiable, Sendable {
    public var id: String
    public var label: String
    public var width: Double?
    public var alignment: HorizontalAlignment
    public var emphasized: Bool
    public init(_ id: String, label: String, width: Double? = nil, alignment: HorizontalAlignment = .leading, emphasized: Bool = false) {
        self.id = id; self.label = label; self.width = width; self.alignment = alignment; self.emphasized = emphasized
    }
}

/// A compact, horizontally scrollable shadcn table. Cells never truncate data.
public struct AITable: View {
    public var columns: [AITableColumn]
    public var rows: [[String: String]]
    public var caption: String?
    public var footer: [String: String]?
    @Theme private var theme
    @ScaledMetric private var scale = 1.0
    public init(columns: [AITableColumn], rows: [[String: String]], caption: String? = nil, footer: [String: String]? = nil) {
        self.columns = columns; self.rows = rows; self.caption = caption; self.footer = footer
    }
    public var body: some View {
        VStack(spacing: 16) {
            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    FoundationTableLayout(columns: columns, width: proxy.size.width, scale: scale) {
                        ForEach(columns) { column in cell(column.label, column: column, weight: .medium, header: true) }
                        ForEach(rows.indices, id: \.self) { row in
                            ForEach(columns) { column in
                                cell(rows[row][column.id] ?? "—", column: column, weight: column.emphasized ? .medium : .regular)
                                    .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
                            }
                        }
                        if let footer {
                            ForEach(columns) { column in
                                cell(footer[column.id] ?? "", column: column, weight: .medium)
                                    .background(theme.muted.opacity(0.5))
                                    .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
                            }
                        }
                    }
                }.foundationTableScrollEdges()
            }.frame(height: (40 + CGFloat(rows.count + (footer == nil ? 0 : 1)) * 37) * scale)
            if let caption {
                NativeTextParagraph(verbatim: caption).environment(\.aiParagraphLineHeight, 20)
                    .environment(\.aiParagraphMuted, true).multilineTextAlignment(.center)
            }
        }
    }
    private func cell(_ value: String, column: AITableColumn, weight: Font.Weight, header: Bool = false) -> some View {
        AITextLabel(value, weight: weight, lineLimit: 1).fixedSize()
            .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: (header ? 40 : 37) * scale,
                                         alignment: column.alignment == .trailing ? .trailing : .leading)
    }
}

private struct FoundationTableLayout: Layout {
    var columns: [AITableColumn]
    var width: CGFloat
    var scale: CGFloat
    func widths(_ subviews: Subviews) -> [CGFloat] {
        guard !columns.isEmpty else { return [] }
        let intrinsic = columns.indices.map { col in
            stride(from: col, to: subviews.count, by: columns.count).map { subviews[$0].sizeThatFits(.unspecified).width }.max() ?? 0
        }
        var result: [CGFloat] = columns.indices.map { max(intrinsic[$0], CGFloat(columns[$0].width ?? 0) * scale) }
        var deficit = max(0, result.reduce(0,+) - width)
        for col in columns.indices {
            let reduction = min(deficit, result[col] - intrinsic[col]); result[col] -= reduction; deficit -= reduction
        }
        let flexible = columns.indices.filter { columns[$0].width == nil }
        let recipients = flexible.isEmpty ? Array(columns.indices) : flexible
        let surplus = max(0, width - result.reduce(0,+)) / CGFloat(recipients.count)
        for col in recipients { result[col] += surplus }
        return result
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: widths(subviews).reduce(0,+), height: columns.isEmpty ? 0 : (40 + CGFloat(max(0, subviews.count / columns.count - 1)) * 37) * scale)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = widths(subviews)
        guard !sizes.isEmpty else { return }
        for index in subviews.indices {
            let col = index % sizes.count, row = index / sizes.count
            let x = bounds.minX + sizes.prefix(col).reduce(0,+)
            let y = bounds.minY + (row == 0 ? 0 : 40 + CGFloat(row - 1) * 37) * scale
            subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: sizes[col], height: (row == 0 ? 40 : 37) * scale))
        }
    }
}

private extension View {
    @ViewBuilder func foundationTableScrollEdges() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) { self.scrollEdgeEffectHidden() }
        else { self }
    }
}
