import Foundation
import Markdown

/// Maps a swift-markdown `Document` onto block kinds.
///
/// This is the only file that knows the swift-markdown AST at block level;
/// ``InlineTextConverter`` does the same for inline content. Supporting a new
/// block kind starts here.
///
/// Code blocks are not rendered as code: a fence's contents become a plain
/// paragraph rather than being dropped, and so does a raw HTML block.
enum MarkdownDocumentConverter {

    struct ConvertedBlock {
        var kind: MarkdownBlock.Kind
        /// 1-based line the block starts on, from cmark's source positions.
        var startLine: Int?
    }

    static func blocks(of document: Document) -> [ConvertedBlock] {
        document.children.compactMap { child in
            kind(of: child).map { ConvertedBlock(kind: $0, startLine: child.range?.lowerBound.line) }
        }
    }

    /// A complete document in one parse: final blocks, positional ids, no
    /// arrivals.
    static func finalBlocks(parsing markdown: String) -> [MarkdownBlock] {
        let document = Document(parsing: LineEndingNormalizer.normalizeAll(markdown))
        return blocks(of: document).enumerated().map { index, block in
            MarkdownBlock(id: index, kind: block.kind, isFinal: true)
        }
    }

    private static func kind(of markup: any Markup) -> MarkdownBlock.Kind? {
        switch markup {
        case let heading as Heading:
            .heading(level: heading.level, text: InlineTextConverter.text(of: heading))
        case let paragraph as Paragraph:
            .paragraph(InlineTextConverter.text(of: paragraph))
        case let codeBlock as CodeBlock:
            .paragraph(AttributedString(literalText(of: codeBlock)))
        case let html as HTMLBlock:
            .paragraph(AttributedString(literalText(of: html)))
        case let quote as BlockQuote:
            .quote(quoteText(of: quote))
        case is ThematicBreak:
            .divider
        case let list as UnorderedList:
            .list(items: items(of: list, level: 0, startingAt: nil))
        case let list as OrderedList:
            .list(items: items(of: list, level: 0, startingAt: Int(list.startIndex)))
        case let table as Table:
            .table(convert(table))
        default:
            InlineTextConverter.plainText(of: markup).map { .paragraph(AttributedString($0)) }
        }
    }

    // MARK: - Quotes

    /// A quote is one run of text, so every child is flattened into it:
    /// paragraphs and headings as their inline content, lists as one line per
    /// item with a marker, code and HTML literally, nested quotes recursively.
    private static func quoteText(of quote: BlockQuote) -> AttributedString {
        let parts = quote.children.compactMap { child -> AttributedString? in
            switch child {
            case let paragraph as Paragraph:
                InlineTextConverter.text(of: paragraph)
            case let heading as Heading:
                InlineTextConverter.text(of: heading)
            case let nested as BlockQuote:
                quoteText(of: nested)
            case let list as UnorderedList:
                listText(items(of: list, level: 0, startingAt: nil))
            case let list as OrderedList:
                listText(items(of: list, level: 0, startingAt: Int(list.startIndex)))
            case let codeBlock as CodeBlock:
                AttributedString(literalText(of: codeBlock))
            case let html as HTMLBlock:
                AttributedString(literalText(of: html))
            default:
                InlineTextConverter.plainText(of: child).map { AttributedString($0) }
            }
        }
        return joined(parts, separator: "\n")
    }

    private static func listText(_ items: [MarkdownListItem]) -> AttributedString {
        joined(items.map { item in
            let marker = item.number.map { "\($0). " } ?? "• "
            return AttributedString(String(repeating: "  ", count: item.level) + marker) + item.text
        }, separator: "\n")
    }

    // MARK: - Lists

    /// Flattens nested lists into one list of level-tagged items, each
    /// followed by its nested items.
    private static func items(of list: any ListItemContainer, level: Int, startingAt start: Int?) -> [MarkdownListItem] {
        var result: [MarkdownListItem] = []
        var number = start

        for item in list.listItems {
            var text = AttributedString()
            var nested: [MarkdownListItem] = []

            for element in item.children {
                switch element {
                case let paragraph as Paragraph:
                    append(InlineTextConverter.text(of: paragraph), to: &text, separator: " ")
                case let unordered as UnorderedList:
                    nested += items(of: unordered, level: level + 1, startingAt: nil)
                case let ordered as OrderedList:
                    nested += items(of: ordered, level: level + 1, startingAt: Int(ordered.startIndex))
                case let codeBlock as CodeBlock:
                    append(AttributedString(literalText(of: codeBlock)), to: &text, separator: "\n")
                default:
                    if let plain = InlineTextConverter.plainText(of: element) {
                        append(AttributedString(plain), to: &text, separator: " ")
                    }
                }
            }

            result.append(MarkdownListItem(
                level: level,
                number: number,
                isChecked: item.checkbox.map { $0 == .checked },
                text: text
            ))
            result += nested
            number = number.map { $0 + 1 }
        }
        return result
    }

    // MARK: - Tables

    private static func convert(_ table: Table) -> MarkdownTable {
        MarkdownTable(
            header: table.head.cells.map { InlineTextConverter.text(of: $0) },
            alignments: table.columnAlignments.map(alignment),
            rows: table.body.rows.map { row in
                row.cells.map { InlineTextConverter.text(of: $0) }
            }
        )
    }

    private static func alignment(_ alignment: Table.ColumnAlignment?) -> MarkdownTable.Alignment {
        switch alignment {
        case .center: .center
        case .right: .trailing
        case .left, nil: .leading
        }
    }

    // MARK: - Helpers

    /// cmark ends fence and HTML content with a newline; a paragraph does
    /// not want it.
    private static func literalText(of codeBlock: CodeBlock) -> String {
        trimmingTrailingNewline(codeBlock.code)
    }

    private static func literalText(of html: HTMLBlock) -> String {
        trimmingTrailingNewline(html.rawHTML)
    }

    private static func trimmingTrailingNewline(_ text: String) -> String {
        text.hasSuffix("\n") ? String(text.dropLast()) : text
    }

    private static func append(_ part: AttributedString, to text: inout AttributedString, separator: String) {
        if !text.characters.isEmpty { text += AttributedString(separator) }
        text += part
    }

    private static func joined(_ parts: [AttributedString], separator: String) -> AttributedString {
        var result = AttributedString()
        for part in parts {
            append(part, to: &result, separator: separator)
        }
        return result
    }
}
