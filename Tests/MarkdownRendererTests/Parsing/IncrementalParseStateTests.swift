import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("IncrementalParseState")
struct IncrementalParseStateTests {

    // MARK: Correctness across chunk boundaries

    @Test("Streaming any fixed chunking yields the same blocks as one-shot parsing", arguments: TestDocuments.all)
    func fixedChunkingIsTransparent(document: TestDocument) {
        let expected = IncrementalMarkdownParser.blocks(parsing: document.markdown)
        #expect(!expected.isEmpty)

        for size in [1, 2, 3, 5, 7, 11, 40, 1000] {
            let streamed = StreamingInvariants.stream(document.markdown.chunked(by: size), context: "\(document.name), size \(size)")
            #expect(streamed.map(\.kind) == expected.map(\.kind), "\(document.name), chunk size \(size)")
        }
    }

    @Test("Chunks cut between the scalars of one character still produce the one-shot text")
    func unicodeSplitAcrossChunks() {
        let markdown = "Café 👨‍👩‍👧 e\u{301}clair **flag 🇺🇸**\n\nnext"
        let chunks = markdown.unicodeScalars.map { String($0) }
        let streamed = StreamingInvariants.stream(chunks, context: "scalar by scalar")
        #expect(streamed.map(\.kind) == IncrementalMarkdownParser.blocks(parsing: markdown).map(\.kind))
    }

    @Test("Windows line endings parse like Unix ones")
    func windowsLineEndings() {
        let unix = IncrementalMarkdownParser.blocks(parsing: "# Title\n\npara\n\n- a\n- b\n")
        let windows = IncrementalMarkdownParser.blocks(parsing: "# Title\r\n\r\npara\r\n\r\n- a\r\n- b\r\n")
        #expect(unix.map(\.kind) == windows.map(\.kind))
    }

    @Test("Windows line endings settle while streaming, even when a chunk splits the pair")
    func windowsLineEndingsSettle() throws {
        var state = IncrementalParseState()
        state.append("# Title\r")
        state.append("\n\r\npara\r\n\r\n| a | b")
        #expect(state.blocks.map(\.isFinal) == [true, true, false])
        let table = try #require(table(state.blocks.last))
        #expect(table.columnCount == 2)
        #expect(state.rawText == "# Title\r\n\r\npara\r\n\r\n| a | b")

        let scanned = state.metrics.charactersScanned
        state.append(" |")
        #expect(state.metrics.charactersScanned - scanned < 40)
    }

    @Test("A chunk ending between \\r and \\n inside a fence does not add a blank line")
    func carriageReturnSplitInsideFence() throws {
        var state = IncrementalParseState()
        for chunk in ["```\r\nline one\r", "\nline two\r", "\n```"] {
            state.append(chunk)
        }
        state.finish()
        #expect(try #require(paragraph(state.blocks.first)) == "line one\nline two")
    }

    @Test("A lone \\r at the very end is released by finish()")
    func trailingCarriageReturn() {
        var state = IncrementalParseState()
        state.append("# One\r")
        state.append("\rtwo\r")
        state.finish()
        #expect(state.blocks.count == 2)
    }

    // MARK: Identity

    @Test("Block ids are positions and settled blocks keep them")
    func idsAreStable() {
        var state = IncrementalParseState()
        state.append("para one\n\npara two\n\npara th")
        let before = state.blocks
        #expect(before.map(\.id) == [0, 1, 2])
        #expect(before.map(\.isFinal) == [true, true, false])

        state.append("ree\n\n# Heading")
        #expect(state.blocks.map(\.id) == [0, 1, 2, 3])
        #expect(Array(state.blocks.prefix(2)) == Array(before.prefix(2)))
    }

    @Test("Several blocks settle in one append and keep their ids")
    func manyBlocksSettleAtOnce() {
        var state = IncrementalParseState()
        state.append("one")
        state.append("\n\ntwo\n\nthree\n\nfour\n\nfi")
        #expect(state.blocks.map(\.id) == [0, 1, 2, 3, 4])
        #expect(state.blocks.map(\.isFinal) == [true, true, true, true, false])
    }

    // MARK: Lifecycle

    @Test("Empty and whitespace-only appends parse nothing")
    func emptyAppends() {
        var state = IncrementalParseState()
        state.append("")
        #expect(state.blocks.isEmpty)
        #expect(state.metrics.parseCount == 0)

        state.append("   \n\n  ")
        #expect(state.blocks.isEmpty)
        #expect(state.rawText == "   \n\n  ")

        state.append("text")
        #expect(state.blocks.count == 1)
    }

    @Test("append returns the snapshot the properties expose, as a value")
    func snapshotIsAValue() {
        var state = IncrementalParseState()
        let first = state.append("# Hi\n\nthere")
        #expect(first == state.snapshot)
        #expect(first.blocks == state.blocks)
        #expect(first.rawText == "# Hi\n\nthere")

        state.append(" and more")
        #expect(first.rawText == "# Hi\n\nthere")
        #expect(first.blocks.count == 2)
    }

    @Test("Metrics count one parse per append that changes the window, plus finish")
    func metricsCountParses() {
        var state = IncrementalParseState()
        state.append("a")
        state.append("b")
        state.append("")
        #expect(state.metrics.parseCount == 2)
        #expect(state.metrics.blockCount == 1)
        #expect(state.metrics.charactersScanned == 3)
        state.finish()
        #expect(state.metrics.parseCount == 3)
        #expect(state.metrics.parseDuration > .zero)
    }

    @Test("finish() makes every block final, and later appends are ignored")
    func finishIsTerminal() {
        var state = IncrementalParseState()
        state.append("one\n\ntwo")
        state.finish()
        #expect(state.isFinished)
        #expect(state.blocks.allSatisfy { $0.isFinal })
        state.append("\n\nthree")
        #expect(state.blocks.count == 2)
        #expect(state.rawText == "one\n\ntwo")
    }

    @Test("finish() is idempotent")
    func finishTwice() {
        var state = IncrementalParseState()
        state.append("one")
        let first = state.finish()
        let second = state.finish()
        #expect(first == second)
        #expect(second.metrics.parseCount == 2)
    }

    @Test("finish() on an empty state yields nothing")
    func finishEmpty() {
        var state = IncrementalParseState()
        let snapshot = state.finish()
        #expect(snapshot.blocks.isEmpty)
        #expect(snapshot.rawText.isEmpty)
    }

    @Test("reset() clears everything, keeps the options and accepts new input")
    func resetClears() {
        var state = IncrementalParseState(options: MarkdownStreamingOptions(repairs: []))
        state.append("one\n\ntwo")
        state.finish()
        state.reset()
        #expect(state.blocks.isEmpty)
        #expect(state.rawText.isEmpty)
        #expect(state.metrics == ParseMetrics())
        #expect(!state.isFinished)
        #expect(state.options.repairs.isEmpty)

        state.append("fresh")
        #expect(state.blocks.map(\.id) == [0])
    }

    // MARK: Settling

    @Test("A trailing blank line settles nothing")
    func trailingBlankLineIsNotABoundary() {
        var state = IncrementalParseState()
        state.append("para\n\n")
        #expect(state.blocks.map(\.isFinal) == [false])
    }

    @Test("A paragraph line directly after a heading stays open until a blank line")
    func headingAndParagraphStayOpenTogether() {
        var state = IncrementalParseState()
        state.append("# Title\nbody")
        #expect(state.blocks.map(\.isFinal) == [false, false])

        state.append("\n\nnext")
        #expect(state.blocks.map(\.isFinal) == [true, true, false])
    }

    @Test("A loose list keeps itself open but lets the blocks before it settle")
    func looseListSettlesWhatCameBefore() throws {
        var state = IncrementalParseState()
        state.append("intro\n\n- a\n\n- b")
        #expect(state.blocks.map(\.isFinal) == [true, false])
        let items = try #require(listItems(state.blocks.last))
        #expect(items.count == 2)

        state.append("\n\n  continued")
        #expect(state.blocks.map(\.isFinal) == [true, false])
    }

    @Test("A blank line inside an open fence never settles", arguments: ["```", "~~~"])
    func blankLineInsideFence(fence: String) throws {
        var state = IncrementalParseState()
        state.append("intro\n\n\(fence)\nline one\n\nline two\n")
        #expect(state.blocks.map(\.isFinal) == [true, false])

        state.append("\(fence)\n\nafter")
        #expect(state.blocks.map(\.isFinal) == [true, true, false])
        #expect(try #require(paragraph(state.blocks[1])) == "line one\n\nline two")
    }

    @Test("A shorter fence or one with an info string does not close a longer fence")
    func nestedFencesStayOpen() throws {
        var state = IncrementalParseState()
        state.append("intro\n\n````\n```swift\nlet a = **1\n```\n\nstill inside **")
        #expect(state.blocks.map(\.isFinal) == [true, false])
        let text = try #require(paragraph(state.blocks.last))
        #expect(text.hasSuffix("still inside **"))

        state.append("\n````\n\nafter")
        #expect(state.blocks.map(\.isFinal) == [true, true, false])
    }

    @Test("Only the open window is re-parsed")
    func reparsesOnlyTheTail() {
        var state = IncrementalParseState()
        for _ in 0..<50 {
            state.append("a paragraph of some length that keeps on going\n\n")
        }
        let scanned = state.metrics.charactersScanned
        state.append("x")
        #expect(state.metrics.charactersScanned - scanned < 100)
    }

    @Test("Scanned characters stay linear over many short blocks")
    func scanningIsLinear() {
        let line = "short paragraph\n\n"
        var state = IncrementalParseState()
        for _ in 0..<200 {
            state.append(line)
        }
        state.finish()
        #expect(state.blocks.count == 200)
        #expect(state.metrics.charactersScanned < line.count * 200 * 3)
    }

    @Test("A long single paragraph streams without dropping text")
    func longParagraph() throws {
        let word = "lorem "
        var state = IncrementalParseState()
        for chunk in String(repeating: word, count: 3500).chunked(by: 64) {
            state.append(chunk)
        }
        state.finish()
        #expect(state.blocks.count == 1)
        #expect(try #require(paragraph(state.blocks.first)).count == word.count * 3500 - 1)
    }

    // MARK: Streaming presentation

    @Test("A table is a table from its first header cell, never a paragraph of pipes")
    func tableNeverShowsPipes() throws {
        var state = IncrementalParseState()
        let table = "| Technique | Fixes | Cost |\n| --- | --- | :---: |\n| Windowing | O(n²) | ~150 lines |\n"
        state.append("Intro line.\n\n")
        var columns: [Int] = []
        for character in table {
            state.append(String(character))
            guard let last = state.blocks.last, last.id == 1 else { continue }
            switch last.kind {
            case .table(let table):
                columns.append(table.columnCount)
            default:
                Issue.record("\(last.kind) shown while the table streamed")
            }
        }
        #expect(columns == columns.sorted())
        #expect(columns.last == 3)
        let finished = try #require(self.table(state.blocks.last))
        #expect(finished.alignments == [.leading, .leading, .center])
        #expect(finished.rows.count == 1)
    }

    @Test("A table header can follow prose without a blank line")
    func tableAfterParagraphLine() throws {
        var state = IncrementalParseState()
        state.append("Numbers:\n| a | b")
        #expect(state.blocks.count == 2)
        #expect(try #require(table(state.blocks.last)).columnCount == 2)
    }

    @Test("A second line that is not a delimiter row means it was never a table")
    func pipeParagraphStaysParagraph() {
        var state = IncrementalParseState()
        state.append("| not a table |\n| just pipes |")
        #expect(state.blocks.count == 1)
        #expect(paragraph(state.blocks.first) != nil)
    }

    @Test("Dangling strong delimiter renders as strong, not asterisks")
    func repairsOpenEmphasis() throws {
        var state = IncrementalParseState()
        state.append("the **impor")
        let text = try #require(attributedParagraph(state.blocks.last))
        #expect(String(text.characters) == "the impor")
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    @Test("A half-arrived link shows its label only, then becomes a link")
    func hidesPartialLink() throws {
        var state = IncrementalParseState()
        state.append("see [the docs](https://ap")
        let partial = try #require(attributedParagraph(state.blocks.last))
        #expect(String(partial.characters) == "see the docs")
        #expect(partial.runs.allSatisfy { $0.link == nil })

        state.append("ple.com) now")
        let complete = try #require(attributedParagraph(state.blocks.last))
        #expect(String(complete.characters) == "see the docs now")
        #expect(complete.runs.contains { $0.link != nil })
    }

    @Test("Repair is not applied once the stream has finished")
    func finishShowsRawTail() throws {
        var state = IncrementalParseState()
        state.append("the **impor")
        state.finish()
        #expect(try #require(paragraph(state.blocks.last)) == "the **impor")
    }

    @Test("Repair never reaches back past a closed fence")
    func repairStopsAtClosedFence() throws {
        var state = IncrementalParseState()
        state.append("~~~\n**x\n~~~\nSome")
        #expect(try #require(paragraph(state.blocks.last)) == "Some")
    }

    @Test("A marker-only last line is withheld until it has content", arguments: [
        "#", "##", "###", "####", "-", "*", "+", ">", ">>", "> ", "|", "`", "```", "~", "~~~",
        "1", "12", "1.", "1)", "12.", "- ", "## ", "> -", "- [", "- [ ", "- [x", "- [X]", "* [ ]", "1. [x",
    ])
    func withholdsMarkerOnlyTail(marker: String) {
        var state = IncrementalParseState()
        state.append("intro\n\n\(marker)")
        #expect(state.blocks.count == 1, "\(marker) should be withheld")
    }

    @Test("Lines that are already content are shown", arguments: [
        "---", "***", "----", "- - -", "* * *", "- x", "1. x", "word", "1.5", "#hash", "1234567890", "[x]", "- [x] done",
    ])
    func keepsContentTail(tail: String) {
        var state = IncrementalParseState()
        state.append("intro\n\n\(tail)")
        #expect(state.blocks.count == 2, "\(tail) should be shown")
    }

    @Test("A task item appears as a task, never as a bracket or an empty bullet")
    func taskItemAppearsWhole() throws {
        var state = IncrementalParseState()
        state.append("intro\n\n")
        for character in "- [x] done" {
            state.append(String(character))
            guard state.blocks.count == 2 else { continue }
            let items = try #require(listItems(state.blocks.last))
            #expect(items.first?.isChecked == true, "shown before the box was complete")
        }
        #expect(try #require(listItems(state.blocks.last)).map { String($0.text.characters) } == ["done"])
    }

    @Test("An ordered item appears as a list item, never as a lone number first")
    func orderedItemAppearsWhole() {
        var state = IncrementalParseState()
        state.append("intro\n\n")
        for character in "12. twelve" {
            state.append(String(character))
            if case .paragraph = state.blocks.last?.kind, state.blocks.count == 2 {
                Issue.record("a paragraph flashed before the list item")
            }
        }
        guard case .list = state.blocks.last?.kind else {
            Issue.record("expected a list")
            return
        }
    }

    @Test("Inside a fence only a half-typed closing fence is withheld")
    func fenceWithholdsOnlyItsCloser() throws {
        var state = IncrementalParseState()
        state.append("```\ncode\n#")
        #expect(try #require(paragraph(state.blocks.last)) == "code\n#")

        state.append("\n``")
        #expect(try #require(paragraph(state.blocks.last)) == "code\n#")
    }

    @Test("A fence is shown as plain text, and repair never reaches inside it")
    func fenceIsPlainAndUnrepaired() throws {
        var state = IncrementalParseState()
        state.append("```\na ** b `c\n")
        let text = try #require(attributedParagraph(state.blocks.last))
        #expect(String(text.characters) == "a ** b `c")
        #expect(text.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }

    // MARK: Helpers

    private func attributedParagraph(_ block: MarkdownBlock?) -> AttributedString? {
        guard case .paragraph(let text) = block?.kind else { return nil }
        return text
    }

    private func paragraph(_ block: MarkdownBlock?) -> String? {
        attributedParagraph(block).map { String($0.characters) }
    }

    private func table(_ block: MarkdownBlock?) -> MarkdownTable? {
        guard case .table(let table) = block?.kind else { return nil }
        return table
    }

    private func listItems(_ block: MarkdownBlock?) -> [MarkdownListItem]? {
        guard case .list(let items) = block?.kind else { return nil }
        return items
    }
}
