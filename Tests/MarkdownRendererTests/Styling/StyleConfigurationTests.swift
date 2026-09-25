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
