import CoreGraphics
import Foundation

/// The arithmetic behind ``TableGridLayout``, kept free of SwiftUI so it can
/// be tested on its own.
///
/// The approach follows SpreadsheetView's layout engine: measure every cell
/// once, keep each column's width and each row's height, and place cells
/// from running totals of those, so asking for a size or placing the cells
/// never measures anything.
struct TableMetrics: Equatable {

    /// Each column is as wide as its widest cell. Cells never wrap.
    var columnWidths: [CGFloat]
    /// Each row is as tall as its tallest cell.
    var rowHeights: [CGFloat]

    /// - Parameter cellSizes: Every cell's size, one array per row, each
    ///   `columnCount` long.
    init(cellSizes: [[CGSize]], columnCount: Int) {
        var widths = Array(repeating: CGFloat(0), count: columnCount)
        for row in cellSizes {
            for (column, size) in row.enumerated() where column < columnCount {
                widths[column] = max(widths[column], size.width)
            }
        }
        self.columnWidths = widths
        self.rowHeights = cellSizes.map { row in row.map(\.height).max() ?? 0 }
    }

    /// The sum of the column widths: the table's width when nothing
    /// stretches it.
    var naturalWidth: CGFloat {
        columnWidths.reduce(0, +)
    }

    var height: CGFloat {
        rowHeights.reduce(0, +)
    }

    /// The column widths for a table drawn `width` wide. Extra width is
    /// shared equally, so every column keeps at least its natural width and
    /// no cell wraps. A narrower or missing `width` leaves the widths as they
    /// are; the table then overflows and scrolls.
    func columnWidths(stretchedTo width: CGFloat?) -> [CGFloat] {
        guard let width, width.isFinite, !columnWidths.isEmpty else { return columnWidths }
        let extra = width - naturalWidth
        guard extra > 0 else { return columnWidths }
        let share = extra / CGFloat(columnWidths.count)
        return columnWidths.map { $0 + share }
    }

    /// Where each column or row starts: the running total of the lengths
    /// before it, starting at 0.
    static func origins(of lengths: [CGFloat]) -> [CGFloat] {
        var origins: [CGFloat] = []
        origins.reserveCapacity(lengths.count)
        var total: CGFloat = 0
        for length in lengths {
            origins.append(total)
            total += length
        }
        return origins
    }

    /// The rows of `new` whose cells need measuring, given the rows the
    /// cached sizes were measured for. While a table streams only its last
    /// row changes and rows are appended, so this is usually one index.
    static func rowsToMeasure(old: [[AttributedString]], new: [[AttributedString]]) -> [Int] {
        new.indices.filter { index in
            !old.indices.contains(index) || old[index] != new[index]
        }
    }
}
