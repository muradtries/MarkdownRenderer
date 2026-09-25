import SwiftUI

/// Lays out table cells, given in row-major order with the header row first
/// and every row `columnCount` long, in a grid whose columns are as wide as
/// their widest cell.
///
/// Every cell is measured once and the sizes are kept in the cache. When the
/// table changes, only the rows that differ from the measured ones are
/// measured again, which while streaming is the row being written. Proposing
/// a size and placing the cells is arithmetic over the cached sizes.
///
/// Offered more width than it needs, the grid shares the extra between its
/// columns; offered less, it keeps its natural width and overflows.
struct TableGridLayout: Layout {

    /// What cell sizes depend on besides the cells' text. When it changes,
    /// every cell is measured again.
    struct MeasurementKey: Equatable, Sendable {
        var theme: MarkdownTheme
        var dynamicTypeSize: DynamicTypeSize
        var legibilityWeight: LegibilityWeight?
    }

    struct Cache {
        var key: MeasurementKey
        var columnCount: Int
        var rows: [[AttributedString]]
        var cellSizes: [[CGSize]]
        var metrics: TableMetrics
    }

    /// Each row's cell text, header first, padded to `columnCount`: what the
    /// cached sizes were measured for.
    let rows: [[AttributedString]]
    let columnCount: Int
    let key: MeasurementKey

    func makeCache(subviews: Subviews) -> Cache {
        var cache = Cache(
            key: key,
            columnCount: columnCount,
            rows: [],
            cellSizes: [],
            metrics: TableMetrics(cellSizes: [], columnCount: columnCount)
        )
        measure(rows: Array(rows.indices), into: &cache, subviews: subviews)
        return cache
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        let isStillValid = cache.key == key && cache.columnCount == columnCount
        let changed = isStillValid ? TableMetrics.rowsToMeasure(old: cache.rows, new: rows) : Array(rows.indices)
        cache.key = key
        cache.columnCount = columnCount
        measure(rows: changed, into: &cache, subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let natural = cache.metrics.naturalWidth
        let width = proposal.width.flatMap { $0.isFinite ? max(natural, $0) : nil } ?? natural
        return CGSize(width: width, height: cache.metrics.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard columnCount > 0 else { return }
        let widths = cache.metrics.columnWidths(stretchedTo: bounds.width)
        let heights = cache.metrics.rowHeights
        let xs = TableMetrics.origins(of: widths)
        let ys = TableMetrics.origins(of: heights)

        for (index, subview) in subviews.enumerated() {
            let row = index / columnCount
            let column = index % columnCount
            guard heights.indices.contains(row) else { return }
            subview.place(
                at: CGPoint(x: bounds.minX + xs[column], y: bounds.minY + ys[row]),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: widths[column], height: heights[row])
            )
        }
    }

    /// Measures the cells of `indices`, drops rows the table no longer has,
    /// and recomputes the column widths and row heights.
    private func measure(rows indices: [Int], into cache: inout Cache, subviews: Subviews) {
        let rowCount = columnCount > 0 ? min(rows.count, subviews.count / columnCount) : 0
        let empty = Array(repeating: CGSize.zero, count: columnCount)

        if cache.cellSizes.count > rowCount {
            cache.cellSizes.removeLast(cache.cellSizes.count - rowCount)
        }
        while cache.cellSizes.count < rowCount {
            cache.cellSizes.append(empty)
        }

        for row in indices where row < rowCount {
            cache.cellSizes[row] = (0..<columnCount).map { column in
                subviews[row * columnCount + column].sizeThatFits(.unspecified)
            }
        }

        cache.rows = Array(rows.prefix(rowCount))
        cache.metrics = TableMetrics(cellSizes: cache.cellSizes, columnCount: columnCount)
    }
}
