import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("Block model")
struct MarkdownModelTests {

    @Test("columnCount is the widest of header and rows")
    func columnCount() {
        let table = MarkdownTable(
            header: [AttributedString("a")],
            alignments: [.leading],
            rows: [[AttributedString("1"), AttributedString("2"), AttributedString("3")], []]
        )
        #expect(table.columnCount == 3)
        #expect(MarkdownTable(header: [], alignments: [], rows: []).columnCount == 0)
    }

    @Test("alignment(for:) falls back to leading outside the declared columns")
    func alignmentFallback() {
        let table = MarkdownTable(header: [], alignments: [.center, .trailing], rows: [])
        #expect(table.alignment(for: 0) == .center)
        #expect(table.alignment(for: 1) == .trailing)
        #expect(table.alignment(for: 2) == .leading)
        #expect(table.alignment(for: -1) == .leading)
    }

    @Test("Only text-bearing blocks have a fadeable length; a list counts every item")
    func fadeableLength() {
        let text = AttributedString("hello")
        #expect(MarkdownBlock.Kind.paragraph(text).fadeableLength == 5)
        #expect(MarkdownBlock.Kind.heading(level: 2, text: text).fadeableLength == 5)
        #expect(MarkdownBlock.Kind.quote(text).fadeableLength == 5)
        #expect(MarkdownBlock.Kind.list(items: [
            MarkdownListItem(level: 0, text: AttributedString("first")),
            MarkdownListItem(level: 1, text: AttributedString("second")),
        ]).fadeableLength == 11)
        #expect(MarkdownBlock.Kind.list(items: []).fadeableLength == 0)
        #expect(MarkdownBlock.Kind.divider.fadeableLength == nil)
        #expect(MarkdownBlock.Kind.table(MarkdownTable(header: [text], alignments: [], rows: [])).fadeableLength == nil)
    }

    @Test("Blocks compare by every field, so a settled block is equal to itself on the next flush")
    func equality() {
        let text = AttributedString("x")
        let settled = MarkdownBlock(id: 3, kind: .paragraph(text), isFinal: true)
        #expect(settled == MarkdownBlock(id: 3, kind: .paragraph(text), isFinal: true))
        #expect(settled != MarkdownBlock(id: 4, kind: .paragraph(text), isFinal: true))
        #expect(settled != MarkdownBlock(id: 3, kind: .paragraph(text), isFinal: false))
        #expect(settled != MarkdownBlock(id: 3, kind: .paragraph(text), isFinal: true, arrivals: [TextArrival(characterCount: 1, time: 0)]))
    }

    @Test("ParseMetrics averages over recorded parses")
    func metrics() {
        var metrics = ParseMetrics()
        #expect(metrics.averageParseMilliseconds == 0)

        metrics.record(parse: .milliseconds(4), characters: 10)
        metrics.record(parse: .milliseconds(2), characters: 5)
        #expect(metrics.parseCount == 2)
        #expect(metrics.charactersScanned == 15)
        #expect(metrics.parseDuration == .milliseconds(6))
        #expect(abs(metrics.averageParseMilliseconds - 3) < 0.0001)
    }

    @Test("Duration.seconds includes the fractional part")
    func durationSeconds() {
        #expect(abs(Duration.milliseconds(1500).seconds - 1.5) < 1e-9)
        #expect(Duration.zero.seconds == 0)
    }
}
