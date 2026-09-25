import Foundation
import Testing
@testable import MarkdownRenderer

/// Exercises the swift-markdown → `MarkdownBlock` mapping through the public
/// one-shot entry point, so these double as tests of `blocks(parsing:)`.
@Suite("MarkdownDocumentConverter")
struct MarkdownDocumentConverterTests {

    // MARK: Headings and paragraphs

    @Test("ATX headings keep their level", arguments: 1...6)
    func headingLevels(level: Int) throws {
        let blocks = IncrementalMarkdownParser.blocks(parsing: String(repeating: "#", count: level) + " Title")
        let block = try #require(blocks.first)
        guard case .heading(let parsed, let text) = block.kind else {
            Issue.record("expected a heading, got \(block.kind)")
            return
        }
        #expect(parsed == level)
        #expect(String(text.characters) == "Title")
    }

    @Test("Setext headings become level 1 and 2")
    func setextHeadings() {
        let blocks = IncrementalMarkdownParser.blocks(parsing: "One\n===\n\nTwo\n---")
        #expect(blocks.count == 2)
        guard case .heading(1, _) = blocks[0].kind, case .heading(2, _) = blocks[1].kind else {
            Issue.record("expected two headings, got \(blocks.map(\.kind))")
            return
        }
    }

    @Test("Empty and whitespace-only input produce no blocks", arguments: ["", "   ", "\n\n", " \n \t\n"])
    func emptyInput(markdown: String) {
        #expect(IncrementalMarkdownParser.blocks(parsing: markdown).isEmpty)
    }

    @Test("Paragraphs are separated by blank lines and joined by lazy continuation")
    func paragraphs() {
        let blocks = IncrementalMarkdownParser.blocks(parsing: "line one\nline two\n\nsecond")
        #expect(blocks.count == 2)
        #expect(paragraph(blocks[0]) == "line one line two")
        #expect(paragraph(blocks[1]) == "second")
    }

    // MARK: Inline content

    @Test("Inline intents land on the right runs")
    func inlineIntents() throws {
        let text = try #require(paragraphText("a **b** *c* `d` ~~e~~ ***f***"))
        #expect(String(text.characters) == "a b c d e f")
        #expect(intent(of: "b", in: text) == .stronglyEmphasized)
        #expect(intent(of: "c", in: text) == .emphasized)
        #expect(intent(of: "d", in: text) == .code)
        #expect(intent(of: "e", in: text) == .strikethrough)
        #expect(intent(of: "f", in: text) == [.stronglyEmphasized, .emphasized])
        #expect(intent(of: "a", in: text) == nil)
    }

    @Test("Links carry their URL and keep nested formatting")
    func links() throws {
        let text = try #require(paragraphText("see [**the** docs](https://example.com/a) now"))
        #expect(String(text.characters) == "see the docs now")
        let linked = text.runs.filter { $0.link != nil }
        #expect(linked.allSatisfy { $0.link == URL(string: "https://example.com/a") })
        let first = try #require(linked.first)
        #expect(String(text[first.range].characters) == "the")
        #expect(intent(of: "the", in: text) == .stronglyEmphasized)
        #expect(text.runs.first?.link == nil)
    }

    @Test("A link whose destination contains spaces is not a link, per CommonMark")
    func invalidLinkDestination() throws {
        let text = try #require(paragraphText("[label](not a url)"))
        #expect(String(text.characters) == "[label](not a url)")
        #expect(text.runs.allSatisfy { $0.link == nil })
    }

    @Test("Images render as their alt text")
    func images() throws {
        let text = try #require(paragraphText("before ![an image](https://x.y/i.png) after"))
        #expect(String(text.characters) == "before an image after")
    }

    @Test("Soft breaks become spaces and hard breaks newlines")
    func lineBreaks() throws {
        let soft = try #require(paragraphText("one\ntwo"))
        #expect(String(soft.characters) == "one two")

        let hard = try #require(paragraphText("one  \ntwo\\\nthree"))
        #expect(String(hard.characters) == "one\ntwo\nthree")
    }

    @Test("Inline HTML is kept literally")
    func inlineHTML() throws {
        let text = try #require(paragraphText("a <b>bold</b> tag"))
        #expect(String(text.characters) == "a <b>bold</b> tag")
    }

    @Test("Escaped characters are unescaped")
    func escapes() throws {
        let text = try #require(paragraphText("not \\*emphasis\\* and \\`code\\`"))
        #expect(String(text.characters) == "not *emphasis* and `code`")
        #expect(text.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }

    // MARK: Lists

    @Test("Bullet lists flatten nesting into levels")
    func nestedBullets() throws {
        let items = try #require(list("- a\n  - b\n    - c\n  - d\n- e"))
        #expect(items.map { String($0.text.characters) } == ["a", "b", "c", "d", "e"])
        #expect(items.map(\.level) == [0, 1, 2, 1, 0])
        #expect(items.allSatisfy { $0.number == nil && $0.isChecked == nil })
    }

    @Test("Ordered lists number from their start and continue after nesting")
    func orderedLists() throws {
        let items = try #require(list("3. three\n4. four\n   1. nested\n5. five"))
        #expect(items.map(\.number) == [3, 4, 1, 5])
        #expect(items.map(\.level) == [0, 0, 1, 0])
    }

    @Test("Task items report their checkbox")
    func taskItems() throws {
        let items = try #require(list("- [x] done\n- [ ] todo\n- plain"))
        #expect(items.map(\.isChecked) == [true, false, nil])
        #expect(items.map { String($0.text.characters) } == ["done", "todo", "plain"])
    }

    @Test("Loose items join their paragraphs with a space, and code with a newline")
    func looseItems() throws {
        let items = try #require(list("- first\n\n  more\n\n- second\n\n  ```\n  code\n  ```"))
        #expect(items.map { String($0.text.characters) } == ["first more", "second\ncode"])
    }

    @Test("Inline formatting inside items is preserved")
    func formattedItems() throws {
        let items = try #require(list("- **bold** item"))
        #expect(intent(of: "bold", in: items[0].text) == .stronglyEmphasized)
    }

    // MARK: Quotes, dividers, code, HTML

    @Test("Quote paragraphs are joined with newlines")
    func quotes() {
        let blocks = IncrementalMarkdownParser.blocks(parsing: "> one\n> still one\n>\n> two **b**")
        #expect(blocks.count == 1)
        guard case .quote(let text) = blocks[0].kind else {
            Issue.record("expected a quote")
            return
        }
        #expect(String(text.characters) == "one still one\ntwo b")
        #expect(intent(of: "b", in: text) == .stronglyEmphasized)
    }

    @Test("Quotes keep lists, headings, code and nested quotes as text")
    func quoteChildren() {
        let markdown = "> # Head\n> - a **b**\n> - c\n>   1. d\n>\n> ```\n> code\n> ```\n>\n> > inner"
        let blocks = IncrementalMarkdownParser.blocks(parsing: markdown)
        #expect(blocks.count == 1)
        guard case .quote(let text) = blocks[0].kind else {
            Issue.record("expected a quote")
            return
        }
        #expect(String(text.characters) == "Head\n• a b\n• c\n  1. d\ncode\ninner")
        #expect(intent(of: "b", in: text) == .stronglyEmphasized)
    }

    @Test("Thematic breaks become dividers", arguments: ["---", "***", "___", "- - -"])
    func dividers(markdown: String) {
        let blocks = IncrementalMarkdownParser.blocks(parsing: markdown)
        #expect(blocks.map(\.kind) == [.divider])
    }

    @Test("Fenced and indented code blocks become plain paragraphs without the trailing newline")
    func codeBlocks() throws {
        let fenced = try #require(paragraphText("```swift\nlet x = **1**\nlet y = 2\n```"))
        #expect(String(fenced.characters) == "let x = **1**\nlet y = 2")
        #expect(fenced.runs.allSatisfy { $0.inlinePresentationIntent == nil })

        let indented = try #require(paragraphText("    indented\n    code"))
        #expect(String(indented.characters) == "indented\ncode")
    }

    @Test("An HTML block is shown literally rather than dropped")
    func htmlBlock() throws {
        let text = try #require(paragraphText("<div>\nhello\n</div>"))
        #expect(String(text.characters) == "<div>\nhello\n</div>")
    }

    // MARK: Tables

    @Test("Tables keep header, alignments and rows")
    func tables() throws {
        let table = try #require(table("| l | c | r | n |\n| :-- | :-: | --: | --- |\n| 1 | 2 | 3 | 4 |\n| 5 | 6 |"))
        #expect(table.header.map { String($0.characters) } == ["l", "c", "r", "n"])
        #expect(table.alignments == [.leading, .center, .trailing, .leading])
        #expect(table.rows.count == 2)
        #expect(table.rows[0].map { String($0.characters) } == ["1", "2", "3", "4"])
        #expect(table.rows[1].map { String($0.characters) } == ["5", "6", "", ""])
        #expect(table.columnCount == 4)
    }

    @Test("Table cells keep inline formatting")
    func tableCells() throws {
        let table = try #require(table("| **h** |\n| --- |\n| `c` |"))
        #expect(intent(of: "h", in: table.header[0]) == .stronglyEmphasized)
        #expect(intent(of: "c", in: table.rows[0][0]) == .code)
    }

    @Test("A document with every block kind converts in order")
    func everyKindInOrder() {
        let kinds = IncrementalMarkdownParser.blocks(parsing: TestDocuments.everything.markdown).map(\.kind)
        let names = kinds.map { kind -> String in
            switch kind {
            case .heading: "heading"
            case .paragraph: "paragraph"
            case .list: "list"
            case .quote: "quote"
            case .table: "table"
            case .divider: "divider"
            }
        }
        #expect(names == [
            "heading", "paragraph", "list", "list", "list", "quote", "paragraph", "table", "divider", "paragraph",
        ])
    }

    @Test("Inline code in a heading carries only the code intent, so it takes the heading's font")
    func codeInHeading() throws {
        let block = try #require(IncrementalMarkdownParser.blocks(parsing: "# Use `fetch` now").first)
        guard case .heading(1, let text) = block.kind else {
            Issue.record("expected a heading, got \(block.kind)")
            return
        }
        #expect(intent(of: "fetch", in: text) == .code)
    }

    @Test("Windows line endings never reach fenced code")
    func windowsLineEndingsInCode() throws {
        let text = try #require(paragraphText("```\r\na\r\nb\r\n```"))
        #expect(String(text.characters) == "a\nb")
    }

    // MARK: Helpers

    private func paragraphText(_ markdown: String) -> AttributedString? {
        guard let block = IncrementalMarkdownParser.blocks(parsing: markdown).first else { return nil }
        return paragraphText(block)
    }

    private func paragraphText(_ block: MarkdownBlock) -> AttributedString? {
        guard case .paragraph(let text) = block.kind else { return nil }
        return text
    }

    private func paragraph(_ block: MarkdownBlock) -> String? {
        paragraphText(block).map { String($0.characters) }
    }

    private func list(_ markdown: String) -> [MarkdownListItem]? {
        guard case .list(let items) = IncrementalMarkdownParser.blocks(parsing: markdown).first?.kind else { return nil }
        return items
    }

    private func table(_ markdown: String) -> MarkdownTable? {
        guard case .table(let table) = IncrementalMarkdownParser.blocks(parsing: markdown).first?.kind else { return nil }
        return table
    }

    /// The intent of the run whose text, ignoring surrounding spaces, is `fragment`.
    private func intent(of fragment: String, in text: AttributedString) -> InlinePresentationIntent? {
        for run in text.runs where String(text[run.range].characters).trimmingCharacters(in: .whitespaces) == fragment {
            return run.inlinePresentationIntent
        }
        Issue.record("no run with text \(fragment) in \(String(text.characters))")
        return nil
    }
}
