import SwiftUI

/// How a thematic break (`---`) is drawn. Install with
/// ``SwiftUI/View/markdownDividerStyle(_:)``.
public protocol MarkdownDividerStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownDividerStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

/// A divider has no content; the configuration exists so the protocol has
/// the same shape as the others and can grow without breaking styles.
public struct MarkdownDividerStyleConfiguration {
    /// The theme in effect where the block is rendered. Styles are not views,
    /// so `@Environment` does not work inside them; read the theme from here.
    public let theme: MarkdownTheme

    init(theme: MarkdownTheme) {
        self.theme = theme
    }
}

/// A system divider with a little vertical room.
public struct DefaultMarkdownDividerStyle: MarkdownDividerStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Divider()
            .padding(.vertical, 2)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Draws every thematic break in this subtree with `style`.
    public func markdownDividerStyle(_ style: some MarkdownDividerStyle) -> some View {
        environment(\.markdownDividerStyle, AnyMarkdownDividerStyle(style))
    }
}

struct AnyMarkdownDividerStyle: MarkdownDividerStyle {
    private let style: any MarkdownDividerStyle

    init(_ style: some MarkdownDividerStyle) {
        self.style = style
    }

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}

extension EnvironmentValues {
    @Entry var markdownDividerStyle = AnyMarkdownDividerStyle(DefaultMarkdownDividerStyle())
}
