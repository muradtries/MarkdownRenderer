import Foundation

/// Gives a re-parsed block the previous flush's storage for every part that
/// did not change.
///
/// The open block is converted from scratch on every flush, so each of its
/// `AttributedString`s is new even where the text is the same. Everything
/// downstream compares blocks: `MarkdownMessageView` to skip settled blocks,
/// SwiftUI to decide which views changed, a table's layout to decide which
/// rows to measure. Two strings or arrays that share storage compare in
/// constant time; two equal ones built separately compare character by
/// character. So the parser, off the main thread, compares the new block
/// with the old one once and keeps the old instance of every equal part: a
/// table's unchanged rows and cells, a list's unchanged items, an unchanged
/// text. Values never change, only which copy is kept.
enum StructuralSharing {

    static func share(_ new: MarkdownBlock.Kind, from old: MarkdownBlock.Kind) -> MarkdownBlock.Kind {
        switch (new, old) {
        case (.table(let newTable), .table(let oldTable)):
            return .table(share(newTable, from: oldTable))

        case (.list(let newItems), .list(let oldItems)):
            return .list(items: shareElements(newItems, from: oldItems))

        case (.paragraph(let newText), .paragraph(let oldText)):
            return newText == oldText ? old : new

        case (.quote(let newText), .quote(let oldText)):
            return newText == oldText ? old : new

        case (.heading(let newLevel, let newText), .heading(let oldLevel, let oldText)):
            return newLevel == oldLevel && newText == oldText ? old : new

        default:
            return new
        }
    }

    static func share(_ new: MarkdownTable, from old: MarkdownTable) -> MarkdownTable {
        MarkdownTable(
            header: shareRow(new.header, from: old.header),
            alignments: new.alignments == old.alignments ? old.alignments : new.alignments,
            rows: new.rows.enumerated().map { index, row in
                old.rows.indices.contains(index) ? shareRow(row, from: old.rows[index]) : row
            }
        )
    }

    /// The old row itself when every cell is equal, so the whole row shares
    /// its storage; otherwise the new row with each equal cell's old text.
    private static func shareRow(_ new: [AttributedString], from old: [AttributedString]) -> [AttributedString] {
        let shared = shareElements(new, from: old)
        return shared.count == old.count && shared == old ? old : shared
    }

    private static func shareElements<Element: Equatable>(_ new: [Element], from old: [Element]) -> [Element] {
        new.enumerated().map { index, element in
            old.indices.contains(index) && old[index] == element ? old[index] : element
        }
    }
}
