import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("MarkdownStreamingOptions")
struct MarkdownStreamingOptionsTests {

    @Test("Defaults: every repair, arrivals on, one second of retention")
    func defaults() {
        let options = MarkdownStreamingOptions()
        #expect(options.repairs == .all)
        #expect(options.tracksArrivals)
        #expect(options.arrivalRetention == 1)
    }

    @Test("With no repairs the stream is shown exactly as cmark parses it")
    func noRepairs() {
        var state = IncrementalParseState(options: MarkdownStreamingOptions(repairs: []))
        state.append("intro\n\nthe **impor")
        #expect(text(state.blocks.last) == "the **impor")
    }

    @Test("Each repair can be turned off on its own", arguments: [
        (MarkdownStreamingOptions.Repairs.withholdMarkers, "intro\n\n-", 2),
        (.hideIncompleteLinks, "intro\n\nsee [docs](http", 2),
        (.closeInlineDelimiters, "intro\n\nthe **impor", 2),
        (.completeTables, "intro\n\n| a | b", 2),
    ])
    func eachRepairIsIndependent(disabled: MarkdownStreamingOptions.Repairs, source: String, blockCount: Int) {
        var withAll = IncrementalParseState()
        withAll.append(source)

        var options = MarkdownStreamingOptions()
        options.repairs.remove(disabled)
        var without = IncrementalParseState(options: options)
        without.append(source)

        #expect(withAll.blocks.map(\.kind) != without.blocks.map(\.kind), "turning off \(disabled.rawValue) changes what is shown")
        #expect(without.blocks.count == blockCount)
    }

    @Test("Partial links show their raw text when link hiding is off")
    func linkHidingOff() {
        var options = MarkdownStreamingOptions()
        options.repairs.remove(.hideIncompleteLinks)
        var state = IncrementalParseState(options: options)
        state.append("see [docs](http")
        #expect(text(state.blocks.last) == "see [docs](http")
    }

    private func text(_ block: MarkdownBlock?) -> String? {
        guard case .paragraph(let text) = block?.kind else { return nil }
        return String(text.characters)
    }
}
