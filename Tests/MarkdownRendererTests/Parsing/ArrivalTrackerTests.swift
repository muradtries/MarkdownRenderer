import Foundation
import Testing
@testable import MarkdownRenderer

@Suite("Arrivals")
struct ArrivalTrackerTests {

    private let clock = TestClock(1000)

    private func makeState(retention: TimeInterval = 1) -> IncrementalParseState {
        let clock = clock
        return IncrementalParseState(options: MarkdownStreamingOptions(arrivalRetention: retention, now: { clock.now }))
    }

    // MARK: The animated block

    @Test("Each flush that grows the last block adds an arrival at the current time")
    func arrivalsTrackTheLastBlock() {
        var state = makeState()
        state.append("hello")
        clock.advance(by: 0.1)
        state.append(" world")
        #expect(state.blocks.last?.arrivals == [
            TextArrival(characterCount: 5, time: 1000),
            TextArrival(characterCount: 11, time: 1000.1),
        ])
    }

    @Test("A flush that does not grow the text adds no arrival")
    func noGrowthNoArrival() {
        var state = makeState()
        state.append("hello")
        clock.advance(by: 0.1)
        state.append("\n-")
        #expect(state.blocks.last?.arrivals == [TextArrival(characterCount: 5, time: 1000)])
    }

    @Test("Tables and dividers carry no arrivals")
    func noArrivalsForUnanimatedBlocks() {
        var state = makeState()
        state.append("| a | b |\n| --- | --- |\n| 1 |")
        #expect(state.blocks.last?.arrivals.isEmpty == true)

        state.append("\n\n---\n\n")
        #expect(state.blocks.last?.arrivals.isEmpty == true)
    }

    @Test("Arrivals are off when the options say so")
    func trackingCanBeTurnedOff() {
        var state = IncrementalParseState(options: MarkdownStreamingOptions(tracksArrivals: false))
        state.append("hello")
        state.append(" world\n\nnext")
        state.finish()
        #expect(state.blocks.allSatisfy { $0.arrivals.isEmpty })
    }

    // MARK: Freezing

    @Test("A block that stops being last keeps its arrivals, so its fade completes")
    func previousBlockKeepsFading() {
        var state = makeState()
        state.append("hello")
        clock.advance(by: 0.1)
        state.append(" world")
        clock.advance(by: 0.1)
        state.append("\n\nnext")

        #expect(state.blocks.map(\.isFinal) == [true, false])
        #expect(state.blocks[0].arrivals.map(\.characterCount) == [5, 11])
        #expect(state.blocks[1].arrivals == [TextArrival(characterCount: 4, time: 1000.2)])
    }

    @Test("A frozen block's arrivals never change, so it stays equal across flushes")
    func frozenArrivalsAreStable() {
        var state = makeState()
        state.append("# Title\nbo")
        let heading = state.blocks[0]
        for _ in 0..<5 {
            clock.advance(by: 0.3)
            state.append("dy")
        }
        #expect(state.blocks[0] == heading)
        #expect(!state.blocks[0].isFinal)
    }

    @Test("A block whose fade is long over freezes with no arrivals and draws as plain text")
    func expiredBlockFreezesEmpty() {
        var state = makeState()
        state.append("hello")
        clock.advance(by: 5)
        state.append("\n\nnext")
        #expect(state.blocks[0].arrivals.isEmpty)
    }

    @Test("finish() keeps every block's arrivals so the last fades complete")
    func finishKeepsArrivals() {
        var state = makeState()
        state.append("one\n\nhello")
        clock.advance(by: 0.1)
        state.append(" world")
        state.finish()
        #expect(state.blocks[0].arrivals.map(\.characterCount) == [3])
        #expect(state.blocks[1].arrivals.map(\.characterCount) == [5, 11])
    }

    @Test("One-shot parsing carries no arrivals", arguments: TestDocuments.all)
    func oneShotHasNoArrivals(document: TestDocument) {
        let blocks = IncrementalMarkdownParser.blocks(parsing: document.markdown)
        #expect(blocks.allSatisfy { $0.arrivals.isEmpty })
    }

    // MARK: Lists

    @Test("List arrivals count over every item, so an earlier item keeps fading when the next starts")
    func listArrivalsSpanItems() {
        var state = makeState()
        state.append("- ab")
        clock.advance(by: 0.1)
        state.append("\n- cd")
        clock.advance(by: 0.1)
        state.append("ef")
        #expect(state.blocks.last?.arrivals == [
            TextArrival(characterCount: 2, time: 1000),
            TextArrival(characterCount: 4, time: 1000.1),
            TextArrival(characterCount: 6, time: 1000.2),
        ])
    }

    // MARK: Expiry

    @Test("After a stall, expired arrivals collapse into one visible marker")
    func staleArrivalsCollapse() {
        var state = makeState()
        state.append("ab")
        clock.advance(by: 0.25)
        state.append("cd")
        clock.advance(by: 0.25)
        state.append("ef")
        clock.advance(by: 5)
        state.append("gh")
        #expect(state.blocks.last?.arrivals == [
            .visible(upTo: 6),
            TextArrival(characterCount: 8, time: 1005.5),
        ])

        clock.advance(by: 0.125)
        state.append("ij")
        #expect(state.blocks.last?.arrivals.map(\.characterCount) == [6, 8, 10])
    }

    @Test("The arrival list stays short however long the block grows")
    func arrivalsStayBounded() {
        var state = makeState(retention: 1)
        for _ in 0..<500 {
            clock.advance(by: 0.05)
            state.append("word ")
        }
        let count = state.blocks.last?.arrivals.count ?? 0
        #expect(count <= 22)
        #expect(state.blocks.last?.arrivals.first?.isVisible == true)
    }

    @Test("When text shrinks, the arrival covering the cut keeps its time")
    func shrinkingTextKeepsArrivalTimes() {
        var state = makeState()
        state.append("a **b")
        clock.advance(by: 0.1)
        state.append("c*")
        #expect(state.blocks.last?.arrivals.map(\.characterCount) == [3, 5], "\"a bc*\" while the closer is half-typed")

        clock.advance(by: 0.1)
        state.append("*")
        #expect(state.blocks.last?.arrivals == [
            TextArrival(characterCount: 3, time: 1000),
            TextArrival(characterCount: 4, time: 1000.1),
        ])
    }

    @Test("Blocks that arrive together fade in together")
    func burstOfBlocksAllFade() {
        var state = makeState()
        state.append("# Title\n\nFirst paragraph.\n\nSecond")
        #expect(state.blocks.map(\.arrivals) == [
            [TextArrival(characterCount: 5, time: 1000)],
            [TextArrival(characterCount: 16, time: 1000)],
            [TextArrival(characterCount: 6, time: 1000)],
        ])
    }

    @Test("A block that takes the place of one that vanished starts with fresh arrivals")
    func vanishedBlockIsForgotten() {
        var tracker = ArrivalTracker(retention: 1)
        var blocks = [paragraph(0, "one"), paragraph(1, "two")]
        tracker.stamp(&blocks, window: 0..<2, now: 10)
        #expect(blocks[1].arrivals == [TextArrival(characterCount: 3, time: 10)])

        blocks = [paragraph(0, "one")]
        tracker.stamp(&blocks, window: 0..<1, now: 11)

        blocks = [paragraph(0, "one"), paragraph(1, "three")]
        tracker.stamp(&blocks, window: 0..<2, now: 12)
        #expect(blocks[1].arrivals == [TextArrival(characterCount: 5, time: 12)])
        #expect(blocks[0].arrivals.isEmpty, "its fade ended long before it was frozen")
    }

    // MARK: Invariants

    @Test("Arrivals stay sorted, distinct and inside the text at every flush", arguments: TestDocuments.all)
    func arrivalsHoldInvariants(document: TestDocument) {
        let clock = clock
        let options = MarkdownStreamingOptions(arrivalRetention: 0.05) {
            clock.advance(by: 0.01)
            return clock.now
        }
        _ = StreamingInvariants.stream(document.markdown.map(String.init), options: options, context: document.name)
    }

    private func paragraph(_ id: Int, _ text: String) -> MarkdownBlock {
        MarkdownBlock(id: id, kind: .paragraph(AttributedString(text)), isFinal: false)
    }
}

@Suite("TextArrival")
struct TextArrivalTests {

    @Test("A visible marker has an infinitely old time")
    func visibleMarker() {
        let marker = TextArrival.visible(upTo: 12)
        #expect(marker.isVisible)
        #expect(marker.characterCount == 12)
        #expect(!TextArrival(characterCount: 12, time: 0).isVisible)
    }

    @Test("Slicing re-counts the stretches that fall inside a range")
    func slicing() {
        let arrivals = [TextArrival.visible(upTo: 40), TextArrival(characterCount: 52, time: 1), TextArrival(characterCount: 60, time: 2)]
        #expect(TextArrival.slice(arrivals, to: 45..<58) == [
            TextArrival(characterCount: 7, time: 1),
            TextArrival(characterCount: 13, time: 2),
        ])
        #expect(TextArrival.slice(arrivals, to: 0..<30) == [.visible(upTo: 30)])
        #expect(TextArrival.slice(arrivals, to: 60..<70) == [])
        #expect(TextArrival.slice(arrivals, to: 40..<40) == [])
        #expect(TextArrival.slice([], to: 0..<10) == [])
    }
}
