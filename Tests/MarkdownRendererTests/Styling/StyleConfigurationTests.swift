import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("Style configurations")
struct StyleConfigurationTests {

    // MARK: Tables

    @Test("Table rows are padded to the column count so a streaming row keeps the grid")
    func paddedRows() {
        let table = MarkdownTable(
            header: [AttributedString("a"), AttributedString("b"), AttributedString("c")],
            alignments: [],
            rows: [[AttributedString("1")]]
        )
        let configuration = MarkdownTableStyleConfiguration(table: table, theme: MarkdownTheme())
        #expect(configuration.columnCount == 3)

        let padded = configuration.cells(of: table.rows[0])
        #expect(padded.map(\.column) == [0, 1, 2])
        #expect(padded.map { String($0.text.characters) } == ["1", "", ""])
        #expect(configuration.cells(of: table.header).map { String($0.text.characters) } == ["a", "b", "c"])
        #expect(configuration.cells(of: []).count == 3)
    }

    @Test("A row wider than the header is not truncated")
    func widerRow() {
        let table = MarkdownTable(
            header: [AttributedString("a")],
            alignments: [],
            rows: [[AttributedString("1"), AttributedString("2")]]
        )
        let configuration = MarkdownTableStyleConfiguration(table: table, theme: MarkdownTheme())
        #expect(configuration.cells(of: table.rows[0]).count == 2)
        #expect(configuration.cells(of: table.header).count == 2)
    }

    @Test("Header cells are column titles, the first body cell a row title, the rest plain cells")
    func cellRoles() {
        let configuration = MarkdownTableStyleConfiguration(table: Self.table, theme: MarkdownTheme())

        #expect(configuration.headerCells.map(\.role) == [.columnTitle, .columnTitle, .columnTitle])
        #expect(configuration.headerCells.allSatisfy { $0.row == nil })
        #expect(configuration.bodyRows.map { $0.map(\.role) } == [
            [.rowTitle, .cell, .cell],
            [.rowTitle, .cell, .cell],
        ])
        #expect(configuration.bodyRows.map { $0.map { $0.row } } == [[0, 0, 0], [1, 1, 1]])
        #expect(configuration.role(row: nil, column: 0) == .columnTitle)
    }

    @Test("Each cell takes the theme's style for its role")
    func cellStyles() {
        var theme = MarkdownTheme()
        theme.tableColumnTitle = MarkdownTableCellStyle(font: .title, foreground: .red)
        theme.tableRowTitle = MarkdownTableCellStyle(font: .headline, foreground: .green)
        theme.tableCell = MarkdownTableCellStyle(font: .caption, foreground: .blue, background: .yellow)
        let configuration = MarkdownTableStyleConfiguration(table: Self.table, theme: theme)

        #expect(configuration.headerCells[0].style == theme.tableColumnTitle)
        #expect(configuration.bodyRows[1][0].style == theme.tableRowTitle)
        #expect(configuration.bodyRows[1][2].style == theme.tableCell)
        #expect(configuration.style(for: .cell) == theme.tableCell)
    }

    @Test("A cell style's alignment overrides the delimiter row's; past its end cells lead")
    func cellAlignment() {
        var theme = MarkdownTheme()
        theme.tableRowTitle.alignment = .trailing
        let configuration = MarkdownTableStyleConfiguration(table: Self.table, theme: theme)

        #expect(configuration.headerCells.map(\.alignment) == [.leading, .center, .leading])
        #expect(configuration.bodyRows[0].map(\.alignment) == [.trailing, .center, .leading])
    }

    @Test("Body rows are padded to the column count, as a streaming row needs")
    func paddedBodyRows() {
        let table = MarkdownTable(
            header: [AttributedString("a"), AttributedString("b")],
            alignments: [],
            rows: [[AttributedString("1")]]
        )
        let configuration = MarkdownTableStyleConfiguration(table: table, theme: MarkdownTheme())
        #expect(configuration.bodyRows[0].map { String($0.text.characters) } == ["1", ""])
        #expect(configuration.bodyRows[0].map(\.id) == [0, 1])
    }

    private static let table = MarkdownTable(
        header: [AttributedString("Name"), AttributedString("Count"), AttributedString("Note")],
        alignments: [.leading, .center],
        rows: [
            [AttributedString("a"), AttributedString("1"), AttributedString("x")],
            [AttributedString("b"), AttributedString("2"), AttributedString("y")],
        ]
    )

    // MARK: Lists

    @Test("Each list item gets its own share of the list's arrivals")
    func listItemArrivals() {
        let items = [
            MarkdownListItem(level: 0, text: AttributedString("first")),
            MarkdownListItem(level: 1, number: 2, text: AttributedString("second")),
            MarkdownListItem(level: 0, isChecked: true, text: AttributedString("third")),
        ]
        let arrivals = [TextArrival.visible(upTo: 7), TextArrival(characterCount: 13, time: 5), TextArrival(characterCount: 16, time: 6)]
        let configuration = MarkdownListStyleConfiguration(items: items, arrivals: arrivals, theme: MarkdownTheme())

        #expect(configuration.items.map(\.id) == [0, 1, 2])
        #expect(configuration.items.map(\.level) == [0, 1, 0])
        #expect(configuration.items.map(\.number) == [nil, 2, nil])
        #expect(configuration.items.map(\.isChecked) == [nil, nil, true])
        #expect(configuration.items[0].arrivals == [.visible(upTo: 5)])
        #expect(configuration.items[1].arrivals == [.visible(upTo: 2), TextArrival(characterCount: 6, time: 5)])
        #expect(configuration.items[2].arrivals == [TextArrival(characterCount: 2, time: 5), TextArrival(characterCount: 5, time: 6)])
    }

    @Test("A list with no arrivals hands every item none")
    func listWithoutArrivals() {
        let items = [MarkdownListItem(level: 0, text: AttributedString("a")), MarkdownListItem(level: 0, text: AttributedString("b"))]
        let configuration = MarkdownListStyleConfiguration(items: items, arrivals: [], theme: MarkdownTheme())
        #expect(configuration.items.allSatisfy { $0.arrivals.isEmpty })
    }

    // MARK: Text blocks

    @Test("Text configurations carry the block's text, arrivals and theme")
    func textConfigurations() {
        let text = AttributedString("hello")
        let arrivals = [TextArrival(characterCount: 5, time: 1)]
        var theme = MarkdownTheme()
        theme.blockSpacing = 99

        let heading = MarkdownHeadingStyleConfiguration(level: 2, text: text, arrivals: arrivals, theme: theme)
        #expect(heading.level == 2)
        #expect(heading.text == text)
        #expect(heading.arrivals == arrivals)
        #expect(heading.theme == theme)

        let paragraph = MarkdownParagraphStyleConfiguration(text: text, arrivals: arrivals, theme: theme)
        #expect(paragraph.text == text)
        #expect(paragraph.arrivals == arrivals)

        let quote = MarkdownQuoteStyleConfiguration(text: text, arrivals: arrivals, theme: theme)
        #expect(quote.text == text)
        #expect(quote.theme.blockSpacing == 99)
    }
}
