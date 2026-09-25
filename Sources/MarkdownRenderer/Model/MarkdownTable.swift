import Foundation

/// A GFM pipe table: a header row, per-column alignments and body rows.
///
/// Rows are not padded. While a table streams in, its last row is usually
/// shorter than the header; ``MarkdownTableStyleConfiguration/cells(of:)``
/// pads a row to ``columnCount`` for layout.
public struct MarkdownTable: Equatable, Sendable {

    public enum Alignment: Equatable, Sendable {
        case leading, center, trailing
    }

    public var header: [AttributedString]

    /// One entry per column the delimiter row declares. Use
    /// ``alignment(for:)``, which falls back to `.leading` past the end.
    public var alignments: [Alignment]

    public var rows: [[AttributedString]]

    public init(header: [AttributedString], alignments: [Alignment], rows: [[AttributedString]]) {
        self.header = header
        self.alignments = alignments
        self.rows = rows
    }

    /// The widest of the header and the rows. Computed on every access, so
    /// read it once per layout pass rather than once per cell.
    public var columnCount: Int {
        rows.reduce(header.count) { max($0, $1.count) }
    }

    public func alignment(for column: Int) -> Alignment {
        alignments.indices.contains(column) ? alignments[column] : .leading
    }
}
