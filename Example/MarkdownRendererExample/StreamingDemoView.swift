import MarkdownRenderer
import SwiftUI

/// The minimal adoption pattern: one parser per reply, `append` per chunk,
/// `finish` when the stream ends, and the snapshot's blocks handed to the view.
///
/// `ObservableObject` rather than `@Observable` because the package's floor is
/// iOS 16; on iOS 17+ an `@Observable` class works the same way.
@MainActor
final class StreamedReply: ObservableObject {

    @Published private(set) var blocks: [MarkdownBlock] = []
    @Published private(set) var metrics = ParseMetrics()
    @Published private(set) var isStreaming = false

    private var parser = IncrementalMarkdownParser()

    /// Replays `markdown` as if it came off the wire, token by token.
    func stream(_ markdown: String, pace: StreamPace) async {
        let parser = IncrementalMarkdownParser()
        self.parser = parser
        blocks = []
        metrics = ParseMetrics()
        isStreaming = true

        let tokens = SampleMarkdown.tokens(of: markdown)
        for start in stride(from: 0, to: tokens.count, by: pace.tokensPerFlush) {
            guard (try? await Task.sleep(for: pace.interval)) != nil else { break }
            let chunk = tokens[start..<min(start + pace.tokensPerFlush, tokens.count)].joined()
            apply(await parser.append(chunk), from: parser)
        }
        apply(await parser.finish(), from: parser)
        if parser === self.parser { isStreaming = false }
    }

    /// A replay that was cancelled mid-stream must not overwrite the one that
    /// replaced it.
    private func apply(_ snapshot: IncrementalMarkdownParser.Snapshot, from parser: IncrementalMarkdownParser) {
        guard parser === self.parser else { return }
        blocks = snapshot.blocks
        metrics = snapshot.metrics
    }
}

/// How the fake backend delivers tokens. `burst` imitates a gateway that
/// buffers a dozen tokens and flushes them at once.
enum StreamPace: String, CaseIterable, Identifiable {
    case slow, fast, burst

    var id: Self { self }

    var tokensPerFlush: Int {
        switch self {
        case .slow, .fast: 1
        case .burst: 12
        }
    }

    var interval: Duration {
        switch self {
        case .slow: .milliseconds(70)
        case .fast: .milliseconds(18)
        case .burst: .milliseconds(260)
        }
    }
}

struct StreamingDemoView: View {

    private struct Run: Hashable {
        var count = 0
        var pace: StreamPace = .fast
    }

    @StateObject private var reply = StreamedReply()
    @State private var run = Run()

    private let bottomAnchor = "bottom"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    MarkdownMessageView(blocks: reply.blocks)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .onChange(of: reply.blocks) { _ in
                    guard reply.isStreaming else { return }
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom) { controls }
            .navigationTitle("Streaming")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        run.count += 1
                    } label: {
                        Label("Replay", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .task(id: run) {
                await reply.stream(SampleMarkdown.document, pace: run.pace)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Pace", selection: $run.pace) {
                ForEach(StreamPace.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(metricsSummary)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    /// `ParseMetrics` shows the windowing at work: characters scanned stay
    /// close to the document length instead of growing quadratically.
    private var metricsSummary: String {
        let metrics = reply.metrics
        return String(
            format: "%d parses · %d chars scanned · %.2f ms avg",
            metrics.parseCount, metrics.charactersScanned, metrics.averageParseMilliseconds
        )
    }
}

#Preview {
    StreamingDemoView()
}
