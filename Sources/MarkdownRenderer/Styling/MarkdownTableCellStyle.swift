import SwiftUI

/// How one kind of table cell looks: column titles, row titles or the rest.
/// The theme holds one of these for each; see
/// ``MarkdownTheme/tableColumnTitle``, ``MarkdownTheme/tableRowTitle`` and
/// ``MarkdownTheme/tableCell``.
///
///     theme.tableRowTitle = MarkdownTableCellStyle(
///         font: .system(size: 13, weight: .semibold),
///         foreground: .primary
///     )
///     theme.tableCell.alignment = .trailing
public struct MarkdownTableCellStyle: Equatable, Sendable {

    /// Font for the cell's text, size included. Bold, italic and inline code
    /// inside the cell take their size from it.
    public var font: Font
    public var foreground: Color
    /// Fill behind the cell. `nil` leaves the row's own fill visible, such as
    /// a zebra stripe.
    public var background: Color?
    /// Overrides the column's alignment from the table's delimiter row.
    /// `nil` follows the markdown.
    public var alignment: MarkdownTable.Alignment?

    public init(
        font: Font,
        foreground: Color,
        background: Color? = nil,
        alignment: MarkdownTable.Alignment? = nil
    ) {
        self.font = font
        self.foreground = foreground
        self.background = background
        self.alignment = alignment
    }
}
