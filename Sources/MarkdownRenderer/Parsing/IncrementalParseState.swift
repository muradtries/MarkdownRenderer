import Foundation
import Markdown

/// The streaming parser as a synchronous value: feed it chunks, read blocks.
///
/// This is the whole state machine behind ``IncrementalMarkdownParser``, with
/// no concurrency attached. Use it directly when you want to decide where
/// parsing runs (inside your own actor, in a test, in a command-line tool);
/// use ``IncrementalMarkdownParser`` for the usual case of parsing off the
/// main actor.
///
///     var state = IncrementalParseState()
///     state.append("# Hel")
///     state.append("lo\n\nworld")
///     state.finish()
///     state.blocks   // [heading "Hello", paragraph "world"]
///
/// ## How it stays cheap
///
/// `Document(parsing:)` parses whole documents, so re-parsing the growing
/// response on every chunk would cost O(n²). Instead the state keeps a
/// *window*: the source of the blocks that can still change. After each parse
/// every block that starts before the last blank-line boundary is settled —
/// marked final, its source dropped from the window — and never looked at
/// again. Each chunk therefore costs about as much as the block being written.
///
/// Before each parse the end of the window is made presentable by
/// ``ProvisionalSource`` (see ``MarkdownStreamingOptions/Repairs``), and
/// after it ``ArrivalTracker`` stamps the fade-in history onto the open blocks.
public struct IncrementalParseState: Sendable {

    /// Everything a consumer reads after a flush, as one value.
    public struct Snapshot: Equatable, Sendable {
        /// Settled blocks followed by the blocks still being written.
        public var blocks: [MarkdownBlock]
        /// Everything fed in so far, verbatim, for copy-to-clipboard.
        public var rawText: String
        public var metrics: ParseMetrics
    }

    public let options: MarkdownStreamingOptions

    /// Settled blocks followed by the blocks still being written.
    public private(set) var blocks: [MarkdownBlock] = []

    /// Everything fed in so far, verbatim.
    public private(set) var rawText = ""

    public private(set) var metrics = ParseMetrics()

    /// `true` after ``finish()``. Later appends are ignored.
    public private(set) var isFinished = false

    public var snapshot: Snapshot {
        Snapshot(blocks: blocks, rawText: rawText, metrics: metrics)
    }

    /// Source of the blocks that can still change, line endings normalized.
    private var window = ""

    /// How many trailing entries of `blocks` were parsed from `window`.
    private var windowBlockCount = 0

    private var lineEndings = LineEndingNormalizer()
    private var arrivals: ArrivalTracker

    public init(options: MarkdownStreamingOptions = MarkdownStreamingOptions()) {
        self.options = options
        self.arrivals = ArrivalTracker(retention: options.arrivalRetention)
    }

    /// Feeds the next chunk. Chunks may split anywhere: mid-word, mid-`**`,
    /// mid-fence, mid-table-row, even between the `\r` and `\n` of a line
    /// break.
    @discardableResult
    public mutating func append(_ chunk: String) -> Snapshot {
        guard !chunk.isEmpty, !isFinished else { return snapshot }
        rawText += chunk
        let normalized = lineEndings.normalize(chunk)
        guard !normalized.isEmpty else { return snapshot }
        window += normalized
        reparseWindow(isStreaming: true)
        return snapshot
    }

    /// Marks the stream complete: the rest of the source is parsed as
    /// written, without streaming repairs, and every block becomes final.
    /// Calling it again does nothing.
    @discardableResult
    public mutating func finish() -> Snapshot {
        guard !isFinished else { return snapshot }
        isFinished = true
        window += lineEndings.flush()
        reparseWindow(isStreaming: false)
        window = ""
        windowBlockCount = 0
        return snapshot
    }

    /// Starts over with the same options, as if newly created.
    public mutating func reset() {
        self = IncrementalParseState(options: options)
    }

    // MARK: - Window

    /// Steps 3 to 8 of "The life of one append" in CONTRIBUTING.md.
    private mutating func reparseWindow(isStreaming: Bool) {
        let scan = WindowScan(window)
        let converted = parseWindow(scan: scan, isStreaming: isStreaming)
        let firstOpen = isStreaming ? Self.firstOpenBlock(in: converted, scan: scan) : converted.count
        let windowBlocks = replaceWindowBlocks(with: converted, firstOpen: firstOpen)

        if options.tracksArrivals {
            arrivals.stamp(&blocks, window: windowBlocks, now: options.now())
        }

        if isStreaming, firstOpen > 0, let startLine = converted[firstOpen].startLine {
            settle(linesBefore: startLine, firstOpenID: windowBlocks.lowerBound + firstOpen)
        } else if converted.isEmpty, window.allSatisfy(\.isWhitespace) {
            window = ""
        }
    }

    /// Repairs the window while streaming, parses it and converts the result,
    /// recording what that cost.
    private mutating func parseWindow(scan: WindowScan, isStreaming: Bool) -> [MarkdownDocumentConverter.ConvertedBlock] {
        let started = ContinuousClock.now
        let source = isStreaming ? ProvisionalSource.make(from: window, scan: scan, repairs: options.repairs) : window
        let converted = MarkdownDocumentConverter.blocks(of: Document(parsing: source))
        metrics.record(parse: started.duration(to: .now), characters: source.count)
        return converted
    }

    /// Swaps the blocks parsed from the window last time for the new ones.
    /// Ids continue from the settled blocks, so a block keeps its id for as
    /// long as it stays at the same position. Returns where they now sit.
    private mutating func replaceWindowBlocks(
        with converted: [MarkdownDocumentConverter.ConvertedBlock],
        firstOpen: Int
    ) -> Range<Int> {
        blocks.removeLast(windowBlockCount)
        let firstID = blocks.count
        for (offset, block) in converted.enumerated() {
            blocks.append(MarkdownBlock(id: firstID + offset, kind: block.kind, isFinal: offset < firstOpen))
        }
        windowBlockCount = converted.count
        metrics.blockCount = blocks.count
        return firstID..<blocks.count
    }

    /// Drops the source of the settled blocks from the window. Their blocks
    /// stay in `blocks`, final, and are never touched again.
    private mutating func settle(linesBefore startLine: Int, firstOpenID: Int) {
        window = Self.dropping(lines: startLine - 1, from: window)
        windowBlockCount = blocks.count - firstOpenID
        arrivals.forgetBlocks(before: firstOpenID)
    }

    /// Index of the first block that may still change: the last block that
    /// starts directly after a blank line. Everything before it is closed by
    /// that blank line and cannot change. `0` when no block qualifies, so
    /// nothing settles; while streaming at least one block always stays open.
    private static func firstOpenBlock(in converted: [MarkdownDocumentConverter.ConvertedBlock], scan: WindowScan) -> Int {
        converted.lastIndex { block in
            block.startLine.map(scan.linesAfterBlankLine.contains) ?? false
        } ?? 0
    }

    private static func dropping(lines count: Int, from source: String) -> String {
        let utf8 = source.utf8
        var start = utf8.startIndex
        for _ in 0..<count {
            guard let newline = utf8[start...].firstIndex(of: .newline) else { return source }
            start = utf8.index(after: newline)
        }
        return String(source[start...])
    }
}
