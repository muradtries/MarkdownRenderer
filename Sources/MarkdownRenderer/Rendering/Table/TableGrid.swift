import SwiftUI

/// The card both built-in table styles draw: the header slot, the grid in a
/// rounded card, and the footer slot, stacked so the slots sit outside the
/// card.
struct TableCard<Header: View, Footer: View>: View {

    let configuration: MarkdownTableStyleConfiguration
    /// Fill behind every other body row, or `nil` for none.
    let stripe: Color?
    let header: (MarkdownTableStyleConfiguration) -> Header
    let footer: (MarkdownTableStyleConfiguration) -> Footer

    var body: some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: theme.tableAccessorySpacing) {
            header(configuration)
            TableGrid(configuration: configuration, stripe: stripe)
                .background(theme.tableBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.tableCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.tableCornerRadius)
                        .stroke(theme.tableBorder, lineWidth: 1)
                )
            footer(configuration)
        }
    }
}

/// The cells in a ``TableGridLayout``, stretched to the offered width when
/// they fit in it and scrolling sideways at their natural width when they do
/// not.
///
/// From iOS 17 there is one copy of the cells, in a scroll view whose content
/// is widened to the viewport at placement (``ViewportStretchLayout``). Below
/// that, `ViewThatFits` chooses between the grid and a scrolling copy of it,
/// which keeps both copies in the view graph.
struct TableGrid: View {

    let configuration: MarkdownTableStyleConfiguration
    let stripe: Color?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight

    var body: some View {
        let cells = cells
        if #available(iOS 17.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                ViewportStretchLayout {
                    Color.clear
                        .frame(height: 0)
                        .containerRelativeFrame(.horizontal)
                        .accessibilityHidden(true)
                    grid(cells)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            ViewThatFits(in: .horizontal) {
                grid(cells)
                ScrollView(.horizontal, showsIndicators: false) {
                    grid(cells)
                }
            }
        }
    }

    /// Every cell, header first, in the row-major order the layout expects.
    private var cells: [TableCellView] {
        let theme = configuration.theme
        let header = configuration.headerCells
        let rows = configuration.bodyRows
        let rule = rows.isEmpty ? nil : theme.tableBorder

        func view(_ cell: MarkdownTableStyleConfiguration.Cell, rowFill: Color?, rule: Color?) -> TableCellView {
            TableCellView(
                text: cell.text,
                style: cell.style,
                alignment: cell.alignment,
                padding: theme.tableCellPadding,
                fill: cell.style.background ?? rowFill,
                rule: rule,
                codeBackground: theme.inlineCodeBackground,
                codeFont: theme.inlineCodeFont,
                isSelectable: theme.isTextSelectable
            )
        }

        var result = header.map { view($0, rowFill: nil, rule: rule) }
        for (index, row) in rows.enumerated() {
            let rowFill = index.isMultiple(of: 2) ? nil : stripe
            result += row.map { view($0, rowFill: rowFill, rule: nil) }
        }
        return result
    }

    private func grid(_ cells: [TableCellView]) -> some View {
        TableGridLayout(
            rows: cells.chunked(into: max(1, configuration.columnCount)).map { $0.map(\.text) },
            columnCount: configuration.columnCount,
            key: TableGridLayout.MeasurementKey(
                theme: configuration.theme,
                dynamicTypeSize: dynamicTypeSize,
                legibilityWeight: legibilityWeight
            )
        ) {
            ForEach(cells.indices, id: \.self) { index in
                cells[index].equatable()
            }
        }
    }
}

/// One cell at its natural size, framed to fill the rectangle the grid
/// places it in, so fills from neighbouring cells meet without gaps.
///
/// Kept to as few views as a cell needs, because a table has hundreds of
/// them: styled `Text` rather than ``MarkdownText`` (cells have no fade-in),
/// one fill, and a rule only on header cells. Equal when what it draws is,
/// so on each flush only the cells that changed run their body.
struct TableCellView: View, Equatable {

    let text: AttributedString
    let style: MarkdownTableCellStyle
    let alignment: MarkdownTable.Alignment
    let padding: EdgeInsets
    /// The cell style's background, or else the row's stripe.
    let fill: Color?
    /// The rule along the bottom of a header cell.
    let rule: Color?
    let codeBackground: Color
    let codeFont: Font?
    let isSelectable: Bool

    var body: some View {
        let content = Text(InlineStyling.styled(text, codeBackground: codeBackground, codeFont: codeFont))
            .font(style.font)
            .foregroundStyle(style.foreground)
            .multilineTextAlignment(TextAlignment(alignment))
            .fixedSize()
            .textSelection(isSelectable)
            .padding(padding)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: Alignment(horizontal: HorizontalAlignment(alignment), vertical: .top)
            )
            .background(fill ?? .clear)

        if let rule {
            content.overlay(alignment: .bottom) {
                Rectangle()
                    .fill(rule)
                    .frame(height: 1)
            }
        } else {
            content
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text
            && lhs.style == rhs.style
            && lhs.alignment == rhs.alignment
            && lhs.padding == rhs.padding
            && lhs.fill == rhs.fill
            && lhs.rule == rhs.rule
            && lhs.codeBackground == rhs.codeBackground
            && lhs.codeFont == rhs.codeFont
            && lhs.isSelectable == rhs.isSelectable
    }
}

private extension Array {
    func chunked(into size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
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
