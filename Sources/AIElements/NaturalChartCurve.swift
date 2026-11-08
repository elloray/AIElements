import SwiftUI

/// Natural cubic interpolation: continuous first/second derivatives, zero end curvature.
/// Equivalent curve family to Recharts `type="natural"`; solved in first derivatives.
enum NaturalChartCurve {
    static func derivatives(_ values: [CGFloat]) -> [CGFloat] {
        let count = values.count
        guard count > 1 else { return Array(repeating: 0, count: count) }
        var diagonal = Array(repeating: CGFloat(4), count: count)
        var rhs = Array(repeating: CGFloat(0), count: count)
        diagonal[0] = 2; diagonal[count - 1] = 2
        rhs[0] = 3 * (values[1] - values[0])
        rhs[count - 1] = 3 * (values[count - 1] - values[count - 2])
        if count > 2 {
            for i in 1..<(count - 1) { rhs[i] = 3 * (values[i + 1] - values[i - 1]) }
        }
        for i in 1..<count {
            let factor = 1 / diagonal[i - 1]
            diagonal[i] -= factor; rhs[i] -= factor * rhs[i - 1]
        }
        var result = rhs
        result[count - 1] /= diagonal[count - 1]
        for i in stride(from: count - 2, through: 0, by: -1) { result[i] = (rhs[i] - result[i + 1]) / diagonal[i] }
        return result
    }
    static func path(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }
        if points.count == 2 { path.addLine(to: points[1]); return path }
        let dx = derivatives(points.map(\.x)), dy = derivatives(points.map(\.y))
        for i in 1..<points.count {
            path.addCurve(to: points[i],
                          control1: CGPoint(x: points[i - 1].x + dx[i - 1] / 3, y: points[i - 1].y + dy[i - 1] / 3),
                          control2: CGPoint(x: points[i].x - dx[i] / 3, y: points[i].y - dy[i] / 3))
        }
        return path
    }
}
