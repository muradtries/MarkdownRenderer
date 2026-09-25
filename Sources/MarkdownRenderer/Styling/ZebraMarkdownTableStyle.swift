import SwiftUI

/// ``DefaultMarkdownTableStyle`` with every other body row filled with the
/// theme's ``MarkdownTheme/tableStripeBackground``, edge to edge. Install as
/// `.zebra`, or with header and footer slots:
///
///     .markdownTableStyle(.zebra)
///
///     .markdownTableStyle(ZebraMarkdownTableStyle { configuration in
///         Text("\(configuration.table.rows.count) rows").font(.caption)
///     })
///
/// The first body row is unfilled, the second filled, and so on. A cell
/// style's own `background` takes the stripe's place in that cell.
public struct ZebraMarkdownTableStyle<Header: View, Footer: View>: MarkdownTableStyle {

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
        TableCard(
            configuration: configuration,
            stripe: configuration.theme.tableStripeBackground,
            header: header,
            footer: footer
        )
    }
}

extension ZebraMarkdownTableStyle where Header == EmptyView, Footer == EmptyView {
    public init() {
        self.init(header: { _ in EmptyView() }, footer: { _ in EmptyView() })
    }
}

extension ZebraMarkdownTableStyle where Header == EmptyView {
    /// - Parameter footer: Drawn below the card, outside it.
    public init(@ViewBuilder footer: @escaping (Configuration) -> Footer) {
        self.init(header: { _ in EmptyView() }, footer: footer)
    }
}

extension ZebraMarkdownTableStyle where Footer == EmptyView {
    /// - Parameter header: Drawn above the card, outside it. Pass it by label;
    ///   a trailing closure alone is the footer.
    @_disfavoredOverload
    public init(@ViewBuilder header: @escaping (Configuration) -> Header) {
        self.init(header: header, footer: { _ in EmptyView() })
    }
}
