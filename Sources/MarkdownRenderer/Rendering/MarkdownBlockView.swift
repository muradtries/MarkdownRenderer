import SwiftUI

/// One block, drawn by the style installed for its kind. This is the default
/// cell of ``MarkdownMessageView``.
///
/// Public so a custom content builder can hand back any block it does not
/// want to draw itself.
///
/// Headings are marked as accessibility headers here rather than in the
/// heading style, so VoiceOver's heading navigation works with any style.
public struct MarkdownBlockView: View {

    private let block: MarkdownBlock

    @Environment(\.markdownTheme) private var theme
    @Environment(\.markdownHeadingStyle) private var headingStyle
    @Environment(\.markdownParagraphStyle) private var paragraphStyle
    @Environment(\.markdownListStyle) private var listStyle
    @Environment(\.markdownQuoteStyle) private var quoteStyle
    @Environment(\.markdownTableStyle) private var tableStyle
    @Environment(\.markdownDividerStyle) private var dividerStyle

    public nonisolated init(block: MarkdownBlock) {
        self.block = block
    }

    public var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            headingStyle.makeBody(configuration: MarkdownHeadingStyleConfiguration(
                level: level,
                text: text,
                arrivals: block.arrivals,
                theme: theme
            ))
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(AccessibilityHeadingLevel(markdownLevel: level))

        case .paragraph(let text):
            paragraphStyle.makeBody(configuration: MarkdownParagraphStyleConfiguration(
                text: text,
                arrivals: block.arrivals,
                theme: theme
            ))

        case .list(let items):
            listStyle.makeBody(configuration: MarkdownListStyleConfiguration(
                items: items,
                arrivals: block.arrivals,
                theme: theme
            ))

        case .quote(let text):
            quoteStyle.makeBody(configuration: MarkdownQuoteStyleConfiguration(
                text: text,
                arrivals: block.arrivals,
                theme: theme
            ))

        case .table(let table):
            tableStyle.makeBody(configuration: MarkdownTableStyleConfiguration(table: table, theme: theme))

        case .divider:
            dividerStyle.makeBody(configuration: MarkdownDividerStyleConfiguration(theme: theme))
        }
    }
}

private extension AccessibilityHeadingLevel {
    init(markdownLevel level: Int) {
        switch level {
        case 1: self = .h1
        case 2: self = .h2
        case 3: self = .h3
        case 4: self = .h4
        case 5: self = .h5
        case 6: self = .h6
        default: self = .unspecified
        }
    }
}
