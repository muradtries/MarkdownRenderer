import SwiftUI

/// How a heading block is drawn. Install with
/// ``SwiftUI/View/markdownHeadingStyle(_:)``.
///
/// Block styles are the second customisation layer and are shaped like
/// `ButtonStyle`: the configuration hands you the inline content as a
/// ready-made view, and you decide what goes around it.
public protocol MarkdownHeadingStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownHeadingStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MarkdownHeadingStyleConfiguration {
    /// The heading's inline content, with the fade-in, and no font applied.
    public let label: MarkdownText
    /// 1 for `#`, 2 for `##`, …
    public let level: Int
    /// The raw inline content, for a style that draws text its own way.
    public let text: AttributedString
    public let arrivals: [TextArrival]
    /// The theme in effect where the block is rendered. Styles are not views,
    /// so `@Environment` does not work inside them; read the theme from here.
    public let theme: MarkdownTheme

    init(level: Int, text: AttributedString, arrivals: [TextArrival], theme: MarkdownTheme) {
        self.label = MarkdownText(text, arrivals: arrivals)
        self.level = level
        self.text = text
        self.arrivals = arrivals
        self.theme = theme
    }
}

/// The theme's heading font for the level, with a little space above.
public struct DefaultMarkdownHeadingStyle: MarkdownHeadingStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let theme = configuration.theme
        configuration.label
            .font(theme.headingFont(level: configuration.level))
            .padding(.top, theme.headingTopPadding(level: configuration.level))
    }
}

extension View {
    /// Draws every heading in this subtree with `style`.
    public func markdownHeadingStyle(_ style: some MarkdownHeadingStyle) -> some View {
        environment(\.markdownHeadingStyle, AnyMarkdownHeadingStyle(style))
    }
}

struct AnyMarkdownHeadingStyle: MarkdownHeadingStyle {
    private let style: any MarkdownHeadingStyle

    init(_ style: some MarkdownHeadingStyle) {
        self.style = style
    }

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}

extension EnvironmentValues {
    @Entry var markdownHeadingStyle = AnyMarkdownHeadingStyle(DefaultMarkdownHeadingStyle())
}
