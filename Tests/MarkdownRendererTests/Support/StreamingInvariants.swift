import Foundation
import Testing
@testable import MarkdownRenderer

/// The promises the streaming parser makes after every append, checked in one
/// place so every streaming test can hold it to all of them.
enum StreamingInvariants {

    /// Checks `current` on its own, and against `previous`, the blocks of the
    /// flush before.
    static func check(
        _ current: [MarkdownBlock],
        after previous: [MarkdownBlock],
        context: @autoclosure () -> String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(current.map(\.id) == Array(current.indices), "ids are positions — \(context())", sourceLocation: sourceLocation)

        let firstOpen = current.firstIndex { !$0.isFinal } ?? current.count
        #expect(current[firstOpen...].allSatisfy { !$0.isFinal }, "final blocks form a prefix — \(context())", sourceLocation: sourceLocation)

        for block in previous where block.isFinal {
            #expect(
                current.indices.contains(block.id) && current[block.id] == block,
                "settled block \(block.id) never changes — \(context())",
                sourceLocation: sourceLocation
            )
        }

        for block in current {
            let counts = block.arrivals.map(\.characterCount)
            #expect(counts == counts.sorted(), "arrivals are sorted — \(context())", sourceLocation: sourceLocation)
            #expect(Set(counts).count == counts.count, "arrivals are distinct — \(context())", sourceLocation: sourceLocation)
            if let length = block.kind.fadeableLength {
                #expect(counts.allSatisfy { $0 <= length }, "arrivals stay inside the text — \(context())", sourceLocation: sourceLocation)
            } else {
                #expect(block.arrivals.isEmpty, "tables and dividers carry no arrivals — \(context())", sourceLocation: sourceLocation)
            }
        }
    }

    /// Streams `chunks` through a fresh state, checking the invariants after
    /// every append, and returns the finished blocks.
    static func stream(
        _ chunks: [String],
        options: MarkdownStreamingOptions = MarkdownStreamingOptions(),
        context: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> [MarkdownBlock] {
        var state = IncrementalParseState(options: options)
        var previous: [MarkdownBlock] = []
        for (index, chunk) in chunks.enumerated() {
            state.append(chunk)
            check(state.blocks, after: previous, context: "\(context), chunk \(index)", sourceLocation: sourceLocation)
            previous = state.blocks
        }
        state.finish()
        check(state.blocks, after: previous, context: "\(context), finish", sourceLocation: sourceLocation)
        #expect(state.blocks.allSatisfy { $0.isFinal }, "finish makes every block final — \(context)", sourceLocation: sourceLocation)
        return state.blocks
    }
}
