import SwiftUI

/// How a block quote is drawn. Install with
/// ``SwiftUI/View/markdownQuoteStyle(_:)``.
public protocol MarkdownQuoteStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownQuoteStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MarkdownQuoteStyleConfiguration {
    /// The quote's inline content, with the fade-in, and no font applied.
    /// Paragraphs inside the quote are joined with newlines.
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

/// A vertical bar with secondary-coloured text beside it.
public struct DefaultMarkdownQuoteStyle: MarkdownQuoteStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let theme = configuration.theme
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(theme.quoteBarColor)
                .frame(width: 3)
                .accessibilityHidden(true)
            configuration.label
                .font(theme.bodyFont)
                .foregroundStyle(theme.quoteForeground)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// Draws every block quote in this subtree with `style`.
    public func markdownQuoteStyle(_ style: some MarkdownQuoteStyle) -> some View {
        environment(\.markdownQuoteStyle, AnyMarkdownQuoteStyle(style))
    }
}

struct AnyMarkdownQuoteStyle: MarkdownQuoteStyle {
    private let style: any MarkdownQuoteStyle

    init(_ style: some MarkdownQuoteStyle) {
        self.style = style
    }

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}

extension EnvironmentValues {
    @Entry var markdownQuoteStyle = AnyMarkdownQuoteStyle(DefaultMarkdownQuoteStyle())
}
