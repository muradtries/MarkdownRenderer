import CoreGraphics
import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("Table metrics")
struct TableMetricsTests {

    private let metrics = TableMetrics(
        cellSizes: [
            [CGSize(width: 40, height: 20), CGSize(width: 30, height: 20)],
            [CGSize(width: 120, height: 18), CGSize(width: 10, height: 34)],
        ],
        columnCount: 2
    )

    // MARK: Measuring

    @Test("A column is as wide as its widest cell, a row as tall as its tallest")
    func naturalSizes() {
        #expect(metrics.columnWidths == [120, 30])
        #expect(metrics.rowHeights == [20, 34])
        #expect(metrics.naturalWidth == 150)
        #expect(metrics.height == 54)
    }

    @Test("A table with no cells has no size")
    func empty() {
        let empty = TableMetrics(cellSizes: [], columnCount: 3)
        #expect(empty.columnWidths == [0, 0, 0])
        #expect(empty.naturalWidth == 0)
        #expect(empty.height == 0)
    }

    // MARK: Stretching

    @Test("Extra width is shared equally between the columns")
    func stretch() {
        #expect(metrics.columnWidths(stretchedTo: 250) == [170, 80])
    }

    @Test("A narrower or missing width keeps the natural widths")
    func noShrink() {
        #expect(metrics.columnWidths(stretchedTo: 100) == [120, 30])
        #expect(metrics.columnWidths(stretchedTo: nil) == [120, 30])
        #expect(metrics.columnWidths(stretchedTo: .infinity) == [120, 30])
    }

    @Test("Origins are running totals starting at zero")
    func origins() {
        #expect(TableMetrics.origins(of: [120, 30, 5]) == [0, 120, 150])
        #expect(TableMetrics.origins(of: []) == [])
    }

    // MARK: Re-measuring

    @Test("Only a row still being written is measured again")
    func growingLastRow() {
        let old = [row("a", "b"), row("1", "2")]
        let new = [row("a", "b"), row("1", "23")]
        #expect(TableMetrics.rowsToMeasure(old: old, new: new) == [1])
    }

    @Test("An appended row is measured, the settled ones are not")
    func appendedRow() {
        let old = [row("a", "b"), row("1", "2")]
        let new = old + [row("3", "")]
        #expect(TableMetrics.rowsToMeasure(old: old, new: new) == [2])
    }

    @Test("An unchanged table measures nothing")
    func unchanged() {
        let rows = [row("a", "b"), row("1", "2")]
        #expect(TableMetrics.rowsToMeasure(old: rows, new: rows).isEmpty)
    }

    @Test("A changed header is measured again")
    func changedHeader() {
        let old = [row("a", "b"), row("1", "2")]
        let new = [row("a", "bc"), row("1", "2")]
        #expect(TableMetrics.rowsToMeasure(old: old, new: new) == [0])
    }

    @Test("Nothing measured yet means every row is measured")
    func firstMeasure() {
        #expect(TableMetrics.rowsToMeasure(old: [], new: [row("a"), row("1")]) == [0, 1])
    }

    private func row(_ cells: String...) -> [AttributedString] {
        cells.map { AttributedString($0) }
    }
}
