import Foundation

/// Turns a stream of text chunks into a growing list of markdown blocks, off
/// the main thread, re-parsing only the blocks that can still change.
///
/// One parser per message. `append` each chunk as it arrives, `finish` when
/// the stream ends, and hand the snapshot's blocks to a
/// ``MarkdownMessageView``:
///
///     let parser = IncrementalMarkdownParser()
///     for try await chunk in stream {
///         message.blocks = await parser.append(chunk).blocks
///     }
///     message.blocks = await parser.finish().blocks
///
/// Each parser is its own actor, so parsing never runs on the main thread,
/// and several messages streaming at once parse in parallel. `append` and
/// `finish` return a ``Snapshot``, so one flush costs one actor hop. The
/// actor is a thin shell around ``IncrementalParseState``, which holds the
/// actual state machine and can be used synchronously.
///
/// Appends are applied in the order they reach the actor. Feed one stream
/// from one task, so that order is the stream's order.
public actor IncrementalMarkdownParser {

    public typealias Snapshot = IncrementalParseState.Snapshot

    private var state: IncrementalParseState

    /// Creatable from any context, so a main-actor model can hold one as a
    /// stored property.
    public init(options: MarkdownStreamingOptions = MarkdownStreamingOptions()) {
        state = IncrementalParseState(options: options)
    }

    /// Settled blocks followed by the blocks still being written.
    public var blocks: [MarkdownBlock] { state.blocks }

    /// Everything fed in so far, verbatim.
    public var rawText: String { state.rawText }

    public var metrics: ParseMetrics { state.metrics }

    public var snapshot: Snapshot { state.snapshot }

    /// Feeds the next chunk. Chunks may split anywhere — mid-word, mid-`**`,
    /// mid-fence, mid-table-row.
    @discardableResult
    public func append(_ chunk: String) -> Snapshot {
        state.append(chunk)
    }

    /// Marks the stream complete: the tail stops being provisional and every
    /// block becomes final.
    @discardableResult
    public func finish() -> Snapshot {
        state.finish()
    }

    /// Starts over with the same options.
    public func reset() {
        state.reset()
    }

    /// Parses a complete document in one pass, for content that is already
    /// fully available: history, previews, tests. Synchronous; it runs on the
    /// caller.
    ///
    /// Every block is final and carries no arrivals, so text that was never
    /// streamed is drawn in full, without the fade-in. The result is what
    /// streaming the same text and calling `finish()` produces.
    public nonisolated static func blocks(parsing markdown: String) -> [MarkdownBlock] {
        MarkdownDocumentConverter.finalBlocks(parsing: markdown)
    }
}
