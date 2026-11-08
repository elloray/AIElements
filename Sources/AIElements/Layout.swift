import SwiftUI

/// Wrapping layout used by source and capability badges.
struct AIFlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 640, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: ProposedViewSize(width: min(bounds.width, subviews[index].sizeThatFits(.unspecified).width), height: nil))
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
private struct ScrollExtentKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
struct AIHorizontalScroll<Content: View>: View {
    @ViewBuilder var content: Content
    @Namespace private var coordinate
    @State private var extent = CGRect.zero
    @State private var width: CGFloat = 1
    var body: some View {
        ScrollView(.horizontal) {
            content.background(GeometryReader { geo in Color.clear.preference(key: ScrollExtentKey.self, value: geo.frame(in: .named(coordinate))) })
        }.scrollIndicators(.hidden).coordinateSpace(name: coordinate)
            .background(GeometryReader { geo in Color.clear.onAppear { width = geo.size.width }.onChange(of: geo.size.width) { _, value in width = value } })
            .onPreferenceChange(ScrollExtentKey.self) { extent = $0 }
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [extent.minX < -1 ? .clear : .black, .black], startPoint: .leading, endPoint: .trailing).frame(width: 16)
                    Rectangle()
                    LinearGradient(colors: [.black, extent.maxX > width + 1 ? .clear : .black], startPoint: .leading, endPoint: .trailing).frame(width: 16)
                }
            }
    }
}
