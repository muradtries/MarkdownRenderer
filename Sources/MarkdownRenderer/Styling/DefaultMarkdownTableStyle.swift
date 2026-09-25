import SwiftUI

/// A rounded card with a rule under the header row, and slots above and
/// below the card for the app's own views:
///
///     .markdownTableStyle(DefaultMarkdownTableStyle { configuration in
///         Button("Export CSV") { export(configuration.table) }
///     })
///
/// The card stretches to the width the rest of the message sets and scrolls
/// sideways when its columns are wider. Cells never wrap: a long cell widens
/// its whole column. Fonts, colours, alignment and fills per cell role come
/// from the theme's ``MarkdownTheme/tableColumnTitle``,
/// ``MarkdownTheme/tableRowTitle`` and ``MarkdownTheme/tableCell``.
public struct DefaultMarkdownTableStyle<Header: View, Footer: View>: MarkdownTableStyle {

    private let header: (Configuration) -> Header
    private let footer: (Configuration) -> Footer

    /// - Parameters:
    ///   - header: Drawn above the card, outside it.
    ///   - footer: Drawn below the card, outside it.
    public init(
        @ViewBuilder header: @escaping (Configuration) -> Header,
        @ViewBuilder footer: @escaping (Configuration) -> Footer
    ) {
        self.header = header
        self.footer = footer
    }

    public func makeBody(configuration: Configuration) -> some View {
        TableCard(configuration: configuration, stripe: nil, header: header, footer: footer)
    }
}

extension DefaultMarkdownTableStyle where Header == EmptyView, Footer == EmptyView {
    public init() {
        self.init(header: { _ in EmptyView() }, footer: { _ in EmptyView() })
    }
}

extension DefaultMarkdownTableStyle where Header == EmptyView {
    /// - Parameter footer: Drawn below the card, outside it.
    public init(@ViewBuilder footer: @escaping (Configuration) -> Footer) {
        self.init(header: { _ in EmptyView() }, footer: footer)
    }
}

extension DefaultMarkdownTableStyle where Footer == EmptyView {
    /// - Parameter header: Drawn above the card, outside it. Pass it by label;
    ///   a trailing closure alone is the footer.
    @_disfavoredOverload
    public init(@ViewBuilder header: @escaping (Configuration) -> Header) {
        self.init(header: header, footer: { _ in EmptyView() })
    }
}
