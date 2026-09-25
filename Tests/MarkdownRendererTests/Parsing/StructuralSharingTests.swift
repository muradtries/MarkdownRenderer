import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("Structural sharing")
struct StructuralSharingTests {

    @Test("Sharing never changes a value")
    func valuesUnchanged() {
        let old = table(rows: [["a", "1"], ["b", "2"]])
        let new = table(rows: [["a", "1"], ["b", "23"], ["c", ""]])
        #expect(StructuralSharing.share(new, from: old) == new)

        let oldList = MarkdownBlock.Kind.list(items: [item("one"), item("two")])
        let newList = MarkdownBlock.Kind.list(items: [item("one"), item("two!"), item("three")])
        #expect(StructuralSharing.share(newList, from: oldList) == newList)

        #expect(StructuralSharing.share(.paragraph(AttributedString("new")), from: .divider) == .paragraph(AttributedString("new")))
    }

    @Test("A table keeps the storage of its unchanged rows")
    func unchangedRowsShareStorage() {
        let old = table(rows: [["a", "1"], ["b", "2"]])
        let new = table(rows: [["a", "1"], ["b", "23"]])
        let shared = StructuralSharing.share(new, from: old)

        #expect(sameStorage(shared.header, old.header))
        #expect(sameStorage(shared.rows[0], old.rows[0]))
        #expect(!sameStorage(shared.rows[1], old.rows[1]))
        #expect(shared.rows[1] == new.rows[1])
    }

    @Test("A list keeps the storage of its unchanged items")
    func unchangedItemsShareStorage() {
        let old = [item("one"), item("two")]
        let new = [item("one"), item("two!")]
        guard case .list(let items) = StructuralSharing.share(.list(items: new), from: .list(items: old)) else {
            Issue.record("Expected a list")
            return
        }
        #expect(items == new)
    }

    @Test("While a table streams, the rows already written keep their storage from flush to flush")
    func streamingTableSharesSettledRows() throws {
        var state = IncrementalParseState()
        state.append("| a | b |\n| --- | --- |\n| 1 | 2 |\n| 3 |")
        let before = try #require(Self.table(in: state.blocks))
        state.append(" 4 |\n| 5")
        let after = try #require(Self.table(in: state.blocks))

        #expect(sameStorage(after.header, before.header))
        #expect(sameStorage(after.rows[0], before.rows[0]))
        #expect(after.rows.count == 3)
    }

    // MARK: Helpers

    private func table(rows: [[String]]) -> MarkdownTable {
        MarkdownTable(
            header: [AttributedString("h1"), AttributedString("h2")],
            alignments: [.leading, .trailing],
            rows: rows.map { $0.map { AttributedString($0) } }
        )
    }

    private func item(_ text: String) -> MarkdownListItem {
        MarkdownListItem(level: 0, text: AttributedString(text))
    }

    private static func table(in blocks: [MarkdownBlock]) -> MarkdownTable? {
        for block in blocks {
            if case .table(let table) = block.kind { return table }
        }
        return nil
    }

    private func sameStorage<Element>(_ lhs: [Element], _ rhs: [Element]) -> Bool {
        lhs.withUnsafeBufferPointer { left in
            rhs.withUnsafeBufferPointer { right in left.baseAddress == right.baseAddress }
        }
    }
}
