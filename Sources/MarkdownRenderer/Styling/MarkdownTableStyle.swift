import SwiftUI

/// How a pipe table is drawn. Install with
/// ``SwiftUI/View/markdownTableStyle(_:)``.
///
/// Two styles ship with the package: ``DefaultMarkdownTableStyle`` and
/// ``ZebraMarkdownTableStyle``, available as `.default` and `.zebra`:
///
///     content.markdownTableStyle(.zebra)
///
/// Tables are the block that looks worst while streaming: the header
/// arrives, then the delimiter row, then the rows one at a time. The whole
/// table is one block so nothing above it reflows; a style should expect
/// short rows and pad them, which ``MarkdownTableStyleConfiguration/headerCells``,
/// ``MarkdownTableStyleConfiguration/bodyRows`` and
/// ``MarkdownTableStyleConfiguration/cells(of:)`` do.
public protocol MarkdownTableStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownTableStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MarkdownTableStyleConfiguration {

    /// Which of the theme's cell styles a cell takes.
    public enum CellRole: Equatable, Sendable {
        /// A cell of the header row, ``MarkdownTheme/tableColumnTitle``.
        case columnTitle
        /// The first cell of a body row, ``MarkdownTheme/tableRowTitle``.
        case rowTitle
        /// Any other body cell, ``MarkdownTheme/tableCell``.
        case cell
    }

    /// One cell, placed and styled.
    public struct Cell: Identifiable {
        /// The body row, counted from 0; `nil` for the header row.
        public let row: Int?
        public let column: Int
        public let role: CellRole
        /// The cell's inline content, with no font applied.
        public let label: MarkdownText
        /// The raw inline content, for a style that draws text its own way.
        public let text: AttributedString
        /// The theme's style for this cell's role.
        public let style: MarkdownTableCellStyle
        /// The style's alignment if it sets one, otherwise the column's.
        public let alignment: MarkdownTable.Alignment

        public var id: Int { column }
    }

    public let table: MarkdownTable

    /// The table's width in columns, computed once for the whole layout pass.
    public let columnCount: Int

    /// The theme in effect where the block is rendered. Styles are not views,
    /// so `@Environment` does not work inside them; read the theme from here.
    public let theme: MarkdownTheme

    init(table: MarkdownTable, theme: MarkdownTheme) {
        self.table = table
        self.columnCount = table.columnCount
        self.theme = theme
    }

    /// The header row, padded to ``columnCount``.
    public var headerCells: [Cell] {
        cells(of: table.header).map { makeCell(row: nil, column: $0.column, text: $0.text) }
    }

    /// The body rows, each padded to ``columnCount``.
    public var bodyRows: [[Cell]] {
        table.rows.enumerated().map { index, row in
            cells(of: row).map { makeCell(row: index, column: $0.column, text: $0.text) }
        }
    }

    /// The role of the cell at `column` in body row `row`, or in the header
    /// when `row` is `nil`. The header's first cell is a column title.
    public func role(row: Int?, column: Int) -> CellRole {
        if row == nil { return .columnTitle }
        return column == 0 ? .rowTitle : .cell
    }

    /// The theme's style for `role`.
    public func style(for role: CellRole) -> MarkdownTableCellStyle {
        switch role {
        case .columnTitle: theme.tableColumnTitle
        case .rowTitle: theme.tableRowTitle
        case .cell: theme.tableCell
        }
    }

    /// The inline content of one cell, with no font applied.
    public func cell(_ text: AttributedString) -> MarkdownText {
        MarkdownText(text)
    }

    /// A row padded to ``columnCount``, so a row still streaming in does not
    /// collapse the grid.
    public func cells(of row: [AttributedString]) -> [(column: Int, text: AttributedString)] {
        let padding = Array(repeating: AttributedString(), count: max(0, columnCount - row.count))
        return (row + padding).enumerated().map { (column: $0.offset, text: $0.element) }
    }

    private func makeCell(row: Int?, column: Int, text: AttributedString) -> Cell {
        let role = role(row: row, column: column)
        let style = style(for: role)
        return Cell(
            row: row,
            column: column,
            role: role,
            label: MarkdownText(text),
            text: text,
            style: style,
            alignment: style.alignment ?? table.alignment(for: column)
        )
    }
}

extension MarkdownTableStyle where Self == DefaultMarkdownTableStyle<EmptyView, EmptyView> {
    /// A card with a rule under the header row.
    public static var `default`: Self { DefaultMarkdownTableStyle() }
}

extension MarkdownTableStyle where Self == ZebraMarkdownTableStyle<EmptyView, EmptyView> {
    /// A card with every other body row filled.
    public static var zebra: Self { ZebraMarkdownTableStyle() }
}

extension View {
    /// Draws every table in this subtree with `style`.
    public func markdownTableStyle(_ style: some MarkdownTableStyle) -> some View {
        environment(\.markdownTableStyle, AnyMarkdownTableStyle(style))
    }
}

struct AnyMarkdownTableStyle: MarkdownTableStyle {
    private let style: any MarkdownTableStyle

    init(_ style: some MarkdownTableStyle) {
        self.style = style
    }

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}

extension EnvironmentValues {
    @Entry var markdownTableStyle = AnyMarkdownTableStyle(DefaultMarkdownTableStyle())
}
