import MarkdownRenderer
import SwiftUI

/// The same document under each customisation layer, so the difference
/// between a theme, a block style and a content builder is visible.
struct StylingDemoView: View {

    enum Look: String, CaseIterable, Identifiable {
        case plain = "Default"
        case theme = "Theme"
        case styles = "Styles"
        case builder = "Builder"

        var id: Self { self }
    }

    @State private var look: Look = Self.initialLook

    /// `--look theme|styles|builder` preselects a segment, for screenshots.
    private static var initialLook: Look {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--look"), index + 1 < arguments.count else { return .plain }
        return Look.allCases.first { $0.rawValue.lowercased() == arguments[index + 1].lowercased() } ?? .plain
    }

    /// Parsed once; a finished document does not need the streaming parser.
    private static let blocks = IncrementalMarkdownParser.blocks(parsing: SampleMarkdown.document)

    var body: some View {
        NavigationStack {
            ScrollView {
                document
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .top) {
                Picker("Look", selection: $look) {
                    ForEach(Look.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle("Styling")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var document: some View {
        switch look {
        case .plain:
            MarkdownMessageView(blocks: Self.blocks)

        case .theme:
            MarkdownMessageView(blocks: Self.blocks)
                .markdownTheme(.example)
                .markdownTableStyle(DefaultMarkdownTableStyle { configuration in
                    CopyTableButton(table: configuration.table)
                })

        case .styles:
            MarkdownMessageView(blocks: Self.blocks)
                .markdownTheme(.example)
                .markdownHeadingStyle(UnderlinedHeadingStyle())
                .markdownListStyle(DashListStyle())
                .markdownQuoteStyle(CalloutQuoteStyle())
                .markdownTableStyle(StripedTableStyle())
                .markdownDividerStyle(DottedDividerStyle())

        case .builder:
            MarkdownMessageView(blocks: Self.blocks) { block in
                switch block.kind {
                case .quote(let text):
                    PullQuoteView(text: text, arrivals: block.arrivals)
                default:
                    MarkdownBlockView(block: block)
                }
            }
        }
    }
}

#Preview {
    StylingDemoView()
}
