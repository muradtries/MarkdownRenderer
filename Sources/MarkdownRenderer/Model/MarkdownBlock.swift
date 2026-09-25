import Foundation

/// A block-level element of a markdown document — a heading, a paragraph, a
/// list, a quote, a table or a divider — with its inline content already
/// resolved to an `AttributedString`.
///
/// Blocks are the unit everything else is built around. While a response
/// streams in, only the last block can still change; everything above it is
/// immutable, so it is never re-parsed, re-styled or re-drawn. Holding
/// attributed text rather than markdown source means the inline work happens
/// once, at parse time, and views only draw.
///
/// Every property is a plain value, so blocks can be stored, compared,
/// sent across actors and rewritten by the app (for example to redact a
/// link) before they reach a view.
public struct MarkdownBlock: Identifiable, Equatable, Sendable {

    /// The block's position in its document: 0 for the first block, 1 for the
    /// next, and so on.
    ///
    /// Positions are stable identities because a settled block never moves:
    /// new content is only ever appended after it. SwiftUI therefore keeps a
    /// block's view, `@State` and text selection across flushes.
    public let id: Int

    public var kind: Kind

    /// `false` while the block is still being written and may change on the
    /// next flush; `true` once nothing can change it.
    public var isFinal: Bool

    /// When each stretch of this block's text arrived, for the fade-in.
    ///
    /// Character counts run over the block's text in reading order; for a
    /// list, that is its items' texts one after another. Empty for text that
    /// was never streamed and for kinds that are not animated (tables,
    /// dividers). See ``TextArrival``.
    public var arrivals: [TextArrival]

    public init(id: Int, kind: Kind, isFinal: Bool, arrivals: [TextArrival] = []) {
        self.id = id
        self.kind = kind
        self.isFinal = isFinal
        self.arrivals = arrivals
    }

    /// What a block is, with the content that kind carries.
    public enum Kind: Equatable, Sendable {
        /// `#` through `######`, or a setext heading. `level` is 1 for `#`.
        case heading(level: Int, text: AttributedString)
        /// Prose. Fenced code and raw HTML blocks are also delivered as
        /// paragraphs of their literal text, so nothing in the input is dropped.
        case paragraph(AttributedString)
        /// A bulleted, numbered or task list. Nested lists are flattened into
        /// one list of items that each carry their nesting `level`.
        case list(items: [MarkdownListItem])
        /// A block quote, flattened to one run of text: paragraphs joined with
        /// newlines, nested lists and quotes written out as text.
        case quote(AttributedString)
        /// A GFM pipe table.
        case table(MarkdownTable)
        /// A thematic break (`---`, `***`, `___`).
        case divider
    }
}
