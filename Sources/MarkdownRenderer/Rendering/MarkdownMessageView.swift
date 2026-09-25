import SwiftUI

/// Renders one message's worth of markdown blocks.
///
/// Feed it the parser's blocks on every flush while a response streams, or
/// a markdown string for a finished one. Every block is its own view with a
/// stable id, and each is compared by value before its body runs, so when a
/// chunk lands SwiftUI re-evaluates the block being written and skips all the
/// settled ones.
///
/// The division of labour is the `UITableView` one: this view owns identity,
/// diffing and the streaming machinery; how a block looks is yours, at
/// whichever level is convenient:
///
/// - ``SwiftUI/View/markdownTheme(_:)`` for values: fonts, spacing, colours;
/// - `.markdown…Style(_:)` for the layout of one block kind, app-wide;
/// - the `content` builder for full control per block, with
///   ``MarkdownBlockView`` as the default to fall back on — the equivalent of
///   `cellForRowAt`:
///
///       MarkdownMessageView(blocks: blocks) { block in
///           switch block.kind {
///           case .table(let table):
///               MyTableView(table)
///           default:
///               MarkdownBlockView(block: block)
///           }
///       }
///
/// The builder runs only when a block changes. State it captures must be
/// read inside the returned view (`@Environment`, `@Binding`), not in the
/// closure body, or a settled block will not see updates — the same rule as a
/// table view cell.
///
/// Chrome around the message — bubbles, avatars, scrolling — belongs to the
/// caller.
public struct MarkdownMessageView<Content: View>: View {

    private enum Source {
        case blocks([MarkdownBlock])
        case markdown(String)
    }

    private let source: Source
    private let content: (MarkdownBlock) -> Content

    public init(blocks: [MarkdownBlock], @ViewBuilder content: @escaping (MarkdownBlock) -> Content) {
        self.source = .blocks(blocks)
        self.content = content
    }

    /// Renders a complete document. It is parsed when the view first appears
    /// and again only when `markdown` changes, never on every update of the
    /// parent. Not for streaming.
    public init(markdown: String, @ViewBuilder content: @escaping (MarkdownBlock) -> Content) {
        self.source = .markdown(markdown)
        self.content = content
    }

    public var body: some View {
        switch source {
        case .blocks(let blocks):
            BlockStack(blocks: blocks, content: content)
        case .markdown(let markdown):
            ParsedMarkdown(markdown: markdown, content: content)
                .equatable()
        }
    }
}

extension MarkdownMessageView where Content == MarkdownBlockView {

    /// Every block drawn by the style installed for its kind.
    public init(blocks: [MarkdownBlock]) {
        self.init(blocks: blocks) { MarkdownBlockView(block: $0) }
    }

    /// Renders a complete document with the installed styles. Not for
    /// streaming.
    public init(markdown: String) {
        self.init(markdown: markdown) { MarkdownBlockView(block: $0) }
    }
}

// MARK: - Building blocks

private struct BlockStack<Content: View>: View {

    let blocks: [MarkdownBlock]
    let content: (MarkdownBlock) -> Content

    @Environment(\.markdownTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
            ForEach(blocks) { block in
                BlockCell(block: block, content: content)
                    .equatable()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The unit of diffing: equal when the block is, so the builder is never
/// invoked for a block that has not changed. Settled blocks keep sharing
/// their text storage between flushes, which makes the comparison O(1).
private struct BlockCell<Content: View>: View, Equatable {

    let block: MarkdownBlock
    let content: (MarkdownBlock) -> Content

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.block == rhs.block
    }

    var body: some View {
        content(block)
    }
}

/// Parses in `body`, and is equal whenever the markdown is, so the parse
/// runs once per distinct document rather than on every parent update.
private struct ParsedMarkdown<Content: View>: View, Equatable {

    let markdown: String
    let content: (MarkdownBlock) -> Content

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.markdown == rhs.markdown
    }

    var body: some View {
        BlockStack(blocks: MarkdownDocumentConverter.finalBlocks(parsing: markdown), content: content)
    }
}
