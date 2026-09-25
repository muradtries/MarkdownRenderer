import SwiftUI

/// How a pipe table is drawn. Install with
/// ``SwiftUI/View/markdownTableStyle(_:)``.
///
/// Tables are the block that looks worst while streaming: the header
/// arrives, then the delimiter row, then the rows one at a time. The whole
/// table is one block so nothing above it reflows; a style should expect
/// short rows and pad them, which ``MarkdownTableStyleConfiguration/cells(of:)``
/// does.
public protocol MarkdownTableStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownTableStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MarkdownTableStyleConfiguration {

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
}

/// A `Grid` with a header rule, inside a rounded, horizontally scrolling
/// card, with a slot under the grid for the app's own controls:
///
///     .markdownTableStyle(DefaultMarkdownTableStyle { configuration in
///         Button("Export CSV") { export(configuration.table) }
///     })
public struct DefaultMarkdownTableStyle<Footer: View>: MarkdownTableStyle {

    private let footer: (Configuration) -> Footer

    public init(@ViewBuilder footer: @escaping (Configuration) -> Footer) {
        self.footer = footer
    }

    public func makeBody(configuration: Configuration) -> some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: 0) {
            grid(configuration)
            footer(configuration)
        }
        .background(theme.tableBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.tableCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.tableCornerRadius)
                .stroke(theme.tableBorder, lineWidth: 1)
        )
    }

    private func grid(_ configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    ForEach(configuration.cells(of: configuration.table.header), id: \.column) { column, text in
                        cell(text, column: column, isHeader: true, configuration: configuration)
                    }
                }
                Divider()
                    .gridCellColumns(max(1, configuration.columnCount))

                ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(configuration.cells(of: row), id: \.column) { column, text in
                            cell(text, column: column, isHeader: false, configuration: configuration)
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func cell(_ text: AttributedString, column: Int, isHeader: Bool, configuration: Configuration) -> some View {
        let theme = configuration.theme
        let alignment = configuration.table.alignment(for: column)
        let styled = configuration.cell(text)
            .font(isHeader ? theme.tableFont.weight(theme.tableHeaderWeight) : theme.tableFont)
            .foregroundStyle(isHeader ? theme.tableHeaderForeground : theme.tableCellForeground)
            .multilineTextAlignment(TextAlignment(alignment))

        if isHeader {
            styled.gridColumnAlignment(HorizontalAlignment(alignment))
        } else {
            styled
        }
    }
}

extension DefaultMarkdownTableStyle where Footer == EmptyView {
    public init() {
        self.init { _ in EmptyView() }
    }
}

private extension TextAlignment {
    init(_ alignment: MarkdownTable.Alignment) {
        switch alignment {
        case .leading: self = .leading
        case .center: self = .center
        case .trailing: self = .trailing
        }
    }
}

private extension HorizontalAlignment {
    init(_ alignment: MarkdownTable.Alignment) {
        switch alignment {
        case .leading: self = .leading
        case .center: self = .center
        case .trailing: self = .trailing
        }
    }
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
