import MarkdownRenderer
import SwiftUI

// MARK: - Layer 1: theme (values only)

extension MarkdownTheme {
    static let example: MarkdownTheme = {
        var theme = MarkdownTheme()
        theme.bodyFont = .system(.body, design: .serif)
        theme.headingFonts = [
            .system(.title, design: .serif).weight(.semibold),
            .system(.title2, design: .serif).weight(.semibold),
            .system(.title3, design: .serif).weight(.semibold),
        ]
        theme.blockSpacing = 16
        theme.tableCornerRadius = 6
        theme.quoteBarColor = .orange
        theme.quoteForeground = .primary
        theme.bulletGlyphs = ["–"]
        theme.inlineCodeBackground = .orange.opacity(0.15)
        theme.tableBackground = .orange.opacity(0.06)
        theme.tableBorder = .orange.opacity(0.25)
        return theme
    }()
}

// MARK: - Layer 2: block styles (layout of one kind)

/// Heading with a hairline beneath the top two levels.
struct UnderlinedHeadingStyle: MarkdownHeadingStyle {
    func makeBody(configuration: Configuration) -> some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
                .font(theme.headingFont(level: configuration.level))
            if configuration.level <= 2 {
                Rectangle().fill(.orange.opacity(0.4)).frame(height: 1)
            }
        }
        .padding(.top, theme.headingTopPadding(level: configuration.level))
    }
}

/// Text-only markers; done task items are struck through.
struct DashListStyle: MarkdownListStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(configuration.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(marker(for: item))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    item.label
                        .strikethrough(item.isChecked == true)
                }
                .padding(.leading, CGFloat(item.level) * 14)
            }
        }
    }

    private func marker(for item: Configuration.Item) -> String {
        if let isChecked = item.isChecked { return isChecked ? "✓" : "○" }
        if let number = item.number { return "\(number))" }
        return "–"
    }
}

/// A tinted callout box instead of a bar.
struct CalloutQuoteStyle: MarkdownQuoteStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .foregroundStyle(.orange)
            configuration.label
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Zebra rows, no card. Built from the model rather than `Grid`, to show that
/// a style can ignore the default layout entirely.
struct StripedTableStyle: MarkdownTableStyle {
    func makeBody(configuration: Configuration) -> some View {
        let table = configuration.table
        VStack(alignment: .leading, spacing: 0) {
            row(configuration, table.header, isHeader: true)
                .background(Color.orange.opacity(0.15))
            ForEach(Array(table.rows.enumerated()), id: \.offset) { index, cells in
                row(configuration, cells, isHeader: false)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func row(_ configuration: Configuration, _ cells: [AttributedString], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(configuration.cells(of: cells), id: \.column) { _, text in
                configuration.cell(text)
                    .font(isHeader ? .footnote.bold() : .footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
    }
}

struct DottedDividerStyle: MarkdownDividerStyle {
    func makeBody(configuration: Configuration) -> some View {
        Text("· · ·")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
}

/// Goes into the default table style's footer slot: the app's own control
/// under the package's grid.
struct CopyTableButton: View {
    let table: MarkdownTable

    var body: some View {
        Button {
            UIPasteboard.general.string = csv
        } label: {
            Label("Copy as CSV", systemImage: "doc.on.doc")
                .font(.footnote)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var csv: String {
        ([table.header] + table.rows)
            .map { row in row.map { String($0.characters) }.joined(separator: ",") }
            .joined(separator: "\n")
    }
}

// MARK: - Layer 3: content builder (any view per block)

/// A quote drawn from the model rather than through a style. It still uses
/// the package's `MarkdownText`, so inline styling and the fade-in are kept.
struct PullQuoteView: View {
    let text: AttributedString
    let arrivals: [TextArrival]

    var body: some View {
        MarkdownText(text, arrivals: arrivals)
            .font(.system(.title3, design: .serif).italic())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(.orange.opacity(0.4)).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(.orange.opacity(0.4)).frame(height: 1) }
    }
}
