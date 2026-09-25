import SwiftUI

/// A run of inline markdown content — a paragraph, a heading's text, one
/// list item, one table cell — with its fade-in.
///
/// Fonts come from the environment, so a `.font(_:)` applied around this view
/// flows into it; bold, italic, code and strikethrough are drawn by `Text` in
/// that font's size and weight. Block styles receive one of these, already
/// built, as their configuration's `label`. A block drawn from the model
/// instead can create one directly, which is the supported way to draw
/// inline content and keep the fade-in:
///
///     MarkdownText(text, arrivals: block.arrivals)
///         .font(.title3)
public struct MarkdownText: View {

    private let text: AttributedString
    private let arrivals: [TextArrival]

    @Environment(\.markdownTheme) private var theme

    /// - Parameters:
    ///   - text: Inline content as produced by the parser.
    ///   - arrivals: Arrival history for the fade-in: a block's `arrivals`,
    ///     or `[]` for static text.
    public nonisolated init(_ text: AttributedString, arrivals: [TextArrival] = []) {
        self.text = text
        self.arrivals = arrivals
    }

    public var body: some View {
        StreamingText(
            text: InlineStyling.styled(text, theme: theme),
            arrivals: theme.fadesInNewText ? arrivals : [],
            curve: FadeCurve(theme)
        )
        .lineSpacing(theme.lineSpacing)
        .textSelection(theme.isTextSelectable)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The presentation `Text` does not derive from semantic attributes on its
/// own: a background behind inline code and an underline under links.
enum InlineStyling {

    static func styled(_ text: AttributedString, theme: MarkdownTheme) -> AttributedString {
        var result = text
        for run in text.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                result[run.range].backgroundColor = theme.inlineCodeBackground
            }
            if run.link != nil {
                result[run.range].underlineStyle = .single
            }
        }
        return result
    }
}

private extension View {
    @ViewBuilder
    func textSelection(_ isEnabled: Bool) -> some View {
        if isEnabled {
            textSelection(.enabled)
        } else {
            textSelection(.disabled)
        }
    }
}
