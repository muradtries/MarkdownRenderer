import SwiftUI

/// How a list block — bulleted, numbered or task list, possibly nested — is
/// drawn. Install with ``SwiftUI/View/markdownListStyle(_:)``.
///
/// Nesting is flattened: every item carries its `level`, so a style lays out
/// one column and indents. Each item's `label` fades in its own part of the
/// list's text.
public protocol MarkdownListStyle {
    associatedtype Body: View
    typealias Configuration = MarkdownListStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MarkdownListStyleConfiguration {

    public struct Item: Identifiable {
        /// Position in the flattened list.
        public let id: Int
        /// The item's inline content, with the fade-in, and no font applied.
        public let label: MarkdownText
        /// Nesting depth, 0 for top level.
        public let level: Int
        /// The item's number in an ordered list, `nil` for a bullet.
        public let number: Int?
        /// `true` or `false` for a task item, `nil` otherwise.
        public let isChecked: Bool?
        /// The raw inline content, for a style that draws text its own way.
        public let text: AttributedString
        /// This item's share of the list's arrivals, counted from the start
        /// of its own text.
        public let arrivals: [TextArrival]
    }

    public let items: [Item]

    /// The theme in effect where the block is rendered. Styles are not views,
    /// so `@Environment` does not work inside them; read the theme from here.
    public let theme: MarkdownTheme

    /// Hands each item the arrivals that fall inside its own text: the list's
    /// arrivals count over every item's text, one after another.
    init(items: [MarkdownListItem], arrivals: [TextArrival], theme: MarkdownTheme) {
        var offset = 0
        self.items = items.enumerated().map { index, item in
            let length = item.text.characters.count
            let itemArrivals = TextArrival.slice(arrivals, to: offset..<(offset + length))
            offset += length
            return Item(
                id: index,
                label: MarkdownText(item.text, arrivals: itemArrivals),
                level: item.level,
                number: item.number,
                isChecked: item.isChecked,
                text: item.text,
                arrivals: itemArrivals
            )
        }
        self.theme = theme
    }
}

/// Glyph bullets, `1.` numbers and SF Symbol checkboxes, indented per level.
public struct DefaultMarkdownListStyle: MarkdownListStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: theme.listItemSpacing) {
            ForEach(configuration.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: theme.listMarkerSpacing) {
                    marker(for: item, theme: theme)
                        .font(theme.bodyFont)
                        .monospacedDigit()
                    item.label
                        .font(theme.bodyFont)
                }
                .padding(.leading, CGFloat(item.level) * theme.listIndent)
            }
        }
    }

    @ViewBuilder
    private func marker(for item: Configuration.Item, theme: MarkdownTheme) -> some View {
        if let isChecked = item.isChecked {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundStyle(isChecked ? theme.checkedColor : theme.bulletColor)
                .accessibilityLabel(isChecked ? "Completed" : "Not completed")
        } else if let number = item.number {
            Text(verbatim: "\(number).")
                .foregroundStyle(theme.numberColor)
        } else {
            Text(verbatim: theme.bulletGlyph(level: item.level))
                .foregroundStyle(theme.bulletColor)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Draws every list in this subtree with `style`.
    public func markdownListStyle(_ style: some MarkdownListStyle) -> some View {
        environment(\.markdownListStyle, AnyMarkdownListStyle(style))
    }
}

struct AnyMarkdownListStyle: MarkdownListStyle {
    private let style: any MarkdownListStyle

    init(_ style: some MarkdownListStyle) {
        self.style = style
    }

    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}

extension EnvironmentValues {
    @Entry var markdownListStyle = AnyMarkdownListStyle(DefaultMarkdownListStyle())
}
