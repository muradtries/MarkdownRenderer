import SwiftUI

/// How a paragraph is drawn. Install with
/// ``SwiftUI/View/markdownParagraphStyle(_:)``.
///
/// Fenced code and raw HTML blocks arrive as paragraphs of their literal
/// text, so they are drawn by this style too.
public protocol MarkdownParagraphStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownParagraphStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MarkdownParagraphStyleConfiguration {
    /// The paragraph's inline content, with the fade-in, and no font applied.
    public let label: MarkdownText
    /// The raw inline content, for a style that draws text its own way.
    public let text: AttributedString
    public let arrivals: [TextArrival]
    /// The theme in effect where the block is rendered. Styles are not views,
    /// so `@Environment` does not work inside them; read the theme from here.
    public let theme: MarkdownTheme

    init(text: AttributedString, arrivals: [TextArrival], theme: MarkdownTheme) {
        self.label = MarkdownText(text, arrivals: arrivals)
        self.text = text
        self.arrivals = arrivals
        self.theme = theme
    }
}

/// The text in the theme's body font.
public struct DefaultMarkdownParagraphStyle: MarkdownParagraphStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(configuration.theme.bodyFont)
    }
}

extension View {
    /// Draws every paragraph in this subtree with `style`.
    public func markdownParagraphStyle(_ style: some MarkdownParagraphStyle) -> some View {
        environment(\.markdownParagraphStyle, AnyMarkdownParagraphStyle(style))
    }
}

struct AnyMarkdownParagraphStyle: MarkdownParagraphStyle {
    private let style: any MarkdownParagraphStyle

    init(_ style: some MarkdownParagraphStyle) {
        self.style = style
    }

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}

extension EnvironmentValues {
    @Entry var markdownParagraphStyle = AnyMarkdownParagraphStyle(DefaultMarkdownParagraphStyle())
}
