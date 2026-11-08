import XCTest
import SwiftUI
@testable import AIElements

final class FoundationChartTests: XCTestCase {
    func testNaturalCurveHasContinuousCurvatureAndNaturalEnds() {
        let values: [CGFloat] = [186, 305, 237, 73, 209, 214]
        let d = NaturalChartCurve.derivatives(values)
        // Hermite second derivatives, evaluated on each side of the knots.
        func left(_ i: Int) -> CGFloat { 6 * (values[i + 1] - values[i]) - 4 * d[i] - 2 * d[i + 1] }
        func right(_ i: Int) -> CGFloat { 6 * (values[i] - values[i + 1]) + 2 * d[i] + 4 * d[i + 1] }
        XCTAssertEqual(left(0), 0, accuracy: 1e-9)
        XCTAssertEqual(right(values.count - 2), 0, accuracy: 1e-9)
        for i in 1..<(values.count - 1) { XCTAssertEqual(right(i - 1), left(i), accuracy: 1e-9) }
        XCTAssertEqual(NaturalChartCurve.derivatives([2, 8]), [6, 6])
        XCTAssertEqual(NaturalChartCurve.derivatives([2]), [0])
        XCTAssertTrue(NaturalChartCurve.derivatives([]).isEmpty)
    }
    func testChartGeometryMatchesReferenceAndHandlesDegenerateData() {
        let rows = [186.0,305,237,73,209,214].enumerated().map { AIChartRow(String($0.offset), values: ["value": $0.element]) }
        let series = [AIChartSeries("value", label: "Value")]
        let line = ChartMetrics(rows: rows, series: series, size: CGSize(width: 310, height: 174), kind: .line)
        XCTAssertEqual(line.x(0), 12); XCTAssertEqual(line.x(5), 298)
        XCTAssertEqual(line.y(186), 60.3, accuracy: 0.001)
        let bar = ChartMetrics(rows: rows, series: series, size: CGSize(width: 310, height: 174), kind: .bar)
        XCTAssertEqual(bar.x(0), 30); XCTAssertEqual(bar.y(0), 139)
        let empty = ChartMetrics(rows: [], series: [], size: .zero, kind: .area)
        XCTAssertTrue(empty.y(0).isFinite)
    }
}
