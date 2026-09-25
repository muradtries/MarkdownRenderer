import SwiftUI

/// Typography, spacing, colours and motion for rendered markdown.
///
/// This is the first customisation layer: values only. Install one with
/// ``SwiftUI/View/markdownTheme(_:)`` on any ancestor and every block below
/// it picks it up, so a chat bubble and a full-width document in the same app
/// can differ. To change a block's *layout* — a different table card, custom
/// list markers — use the block style protocols (``MarkdownTableStyle`` and
/// friends); the default styles read their values from here.
///
///     var theme = MarkdownTheme()
///     theme.bodyFont = .callout
///     theme.fadesInNewText = false
///     content.markdownTheme(theme)
public struct MarkdownTheme: Equatable, Sendable {

    // MARK: Text

    /// Font for paragraphs, list items and quotes. Inline code, bold and
    /// italic take their size from it.
    public var bodyFont: Font = .body
    public var lineSpacing: CGFloat = 3
    /// Space between blocks.
    public var blockSpacing: CGFloat = 12
    /// Background behind inline `code` spans.
    public var inlineCodeBackground: Color = .primary.opacity(0.08)
    /// Whether text can be selected and copied. Selection costs memory per
    /// text view; turn it off for long transcripts that do not need it.
    public var isTextSelectable = true

    // MARK: Headings

    /// Fonts for heading levels 1…n. A deeper heading reuses the last entry.
    public var headingFonts: [Font] = [
        .title2.weight(.bold),
        .title3.weight(.bold),
        .headline,
        .subheadline.weight(.semibold),
    ]
    /// Extra space above heading levels 1…n. A deeper heading reuses the last
    /// entry.
    public var headingTopPadding: [CGFloat] = [6, 6, 2]

    // MARK: Lists

    public var listItemSpacing: CGFloat = 6
    /// Indent per nesting level.
    public var listIndent: CGFloat = 18
    /// Space between a marker and its item's text.
    public var listMarkerSpacing: CGFloat = 8
    /// Bullet glyphs for nesting levels 0…n. A deeper item reuses the last
    /// entry.
    public var bulletGlyphs: [String] = ["•", "◦", "▪"]
    public var bulletColor: Color = .secondary
    public var numberColor: Color = .primary
    /// Tint of a checked task-list box.
    public var checkedColor: Color = .accentColor

    // MARK: Quotes

    /// The bar beside a block quote.
    public var quoteBarColor: Color = .accentColor.opacity(0.5)
    /// Text colour inside a block quote.
    public var quoteForeground: Color = .secondary

    // MARK: Tables

    public var tableFont: Font = .footnote
    /// Weight applied to header cells on top of `tableFont`.
    public var tableHeaderWeight: Font.Weight = .semibold
    public var tableHeaderForeground: Color = .primary
    public var tableCellForeground: Color = .secondary
    public var tableBackground: Color = .primary.opacity(0.045)
    public var tableBorder: Color = .primary.opacity(0.08)
    public var tableCornerRadius: CGFloat = 12

    // MARK: Fade-in

    /// Whether newly arrived text fades in. iOS 18 and later; below that text
    /// appears without animation.
    public var fadesInNewText = true
    /// How long one glyph takes to go from transparent to opaque.
    public var fadeInDuration: TimeInterval = 0.45
    /// Delay between consecutive glyphs of one stretch of text, so a batch
    /// reads as typed rather than appearing as a slab.
    public var fadeInStagger: TimeInterval = 0.006

    public init() {}

    // MARK: Lookups

    public func headingFont(level: Int) -> Font {
        entry(of: headingFonts, at: level - 1) ?? bodyFont
    }

    public func headingTopPadding(level: Int) -> CGFloat {
        entry(of: headingTopPadding, at: level - 1) ?? 0
    }

    public func bulletGlyph(level: Int) -> String {
        entry(of: bulletGlyphs, at: level) ?? "•"
    }

    /// The entry at `index`, clamped to the array, so a deeper level reuses
    /// the last entry. `nil` only for an empty array.
    private func entry<Value>(of values: [Value], at index: Int) -> Value? {
        guard !values.isEmpty else { return nil }
        return values[min(max(0, index), values.count - 1)]
    }
}

extension EnvironmentValues {
    @Entry public var markdownTheme = MarkdownTheme()
}

extension View {
    /// Applies a theme to every markdown view in this subtree.
    public func markdownTheme(_ theme: MarkdownTheme) -> some View {
        environment(\.markdownTheme, theme)
    }
}
