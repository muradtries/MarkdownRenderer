import Foundation

/// Choices about how a response looks while it is still arriving.
///
/// None of these change the finished document: `finish()` always parses the
/// remaining source exactly as written. They only decide what the reader sees
/// between chunks.
///
///     var options = MarkdownStreamingOptions()
///     options.repairs.remove(.hideIncompleteLinks)
///     let parser = IncrementalMarkdownParser(options: options)
public struct MarkdownStreamingOptions: Sendable {

    /// Fixes applied to the unfinished end of the stream before each parse,
    /// so half-arrived syntax never flashes on screen as raw characters.
    public struct Repairs: OptionSet, Sendable {

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Holds back a last line that is only a block marker — `-`, `##`,
        /// `>`, `1.`, `|`, `- [ ]`, the start of a fence — until its content
        /// arrives, so it never shows as a one-frame paragraph.
        public static let withholdMarkers = Repairs(rawValue: 1 << 0)

        /// Shows a half-arrived link as its label until the closing `)`
        /// arrives, so a partial URL never crawls across the screen.
        public static let hideIncompleteLinks = Repairs(rawValue: 1 << 1)

        /// Closes dangling `**`, `_`, `~~` and backticks, so `**bo` is drawn
        /// bold instead of as two asterisks.
        public static let closeInlineDelimiters = Repairs(rawValue: 1 << 2)

        /// Synthesises a table's delimiter row from its header, so a table is
        /// a table from its first cell instead of a paragraph of pipes.
        public static let completeTables = Repairs(rawValue: 1 << 3)

        public static let all: Repairs = [.withholdMarkers, .hideIncompleteLinks, .closeInlineDelimiters, .completeTables]
    }

    /// Which repairs run while streaming. All of them by default; `[]` shows
    /// the raw stream as cmark parses it.
    public var repairs: Repairs

    /// Whether blocks carry ``MarkdownBlock/arrivals``. Turn it off when
    /// nothing fades in (``MarkdownTheme/fadesInNewText`` is `false`) to keep
    /// timing data out of the blocks.
    public var tracksArrivals: Bool

    /// How long an arrival is kept before its text counts as fully visible.
    ///
    /// Must be at least as long as the longest fade the view draws —
    /// ``MarkdownTheme/fadeInDuration`` plus the stagger across one line —
    /// or text still fading snaps to full opacity.
    public var arrivalRetention: TimeInterval

    /// The clock arrivals are stamped with, in
    /// `Date.timeIntervalSinceReferenceDate`. Replace it to make arrivals
    /// deterministic in tests.
    public var now: @Sendable () -> TimeInterval

    public init(
        repairs: Repairs = .all,
        tracksArrivals: Bool = true,
        arrivalRetention: TimeInterval = 1,
        now: @escaping @Sendable () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    ) {
        self.repairs = repairs
        self.tracksArrivals = tracksArrivals
        self.arrivalRetention = arrivalRetention
        self.now = now
    }
}
