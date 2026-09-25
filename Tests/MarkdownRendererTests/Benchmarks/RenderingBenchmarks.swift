import SwiftUI
import Testing
import UIKit
@testable import MarkdownRenderer

/// Layout cost of the views, measured the way an app pays it: a hosted
/// `MarkdownMessageView` in a window, updated with each flush of a stream
/// and laid out synchronously. Printed rather than asserted, like
/// ``ParserBenchmarks``, and off unless `MARKDOWN_BENCHMARKS` is set:
///
///     test_sim  -only-testing:MarkdownRendererTests/RenderingBenchmarks
///               -configuration Release ENABLE_TESTABILITY=YES
///               testRunnerEnv: MARKDOWN_BENCHMARKS=1
///
/// Besides wall time, each scenario counts how often SwiftUI asked a block
/// for its size, through a pass-through layout around every block. The
/// count is deterministic, so it shows a change in layout work even where
/// timings are noisy.
@MainActor
@Suite("RenderingBenchmarks", .serialized, .enabled(if: ProcessInfo.processInfo.environment["MARKDOWN_BENCHMARKS"] != nil))
struct RenderingBenchmarks {

    @Test("A long mixed reply, streamed")
    func longReply() {
        let markdown = String(
            repeating: TestDocuments.everything.markdown + "\n\n" + TestDocuments.tables.markdown + "\n\n",
            count: 4
        )
        run("long mixed reply", flushes: Self.flushes(streaming: markdown))
    }

    @Test("A long table, streamed")
    func longTable() {
        let header = "| Name | Region | Units | Price | Note |\n| --- | --- | ---: | ---: | --- |\n"
        let rows = (0..<80).map { "| item \($0) | eu-\($0 % 7) | \($0 * 13) | \($0 * 3).99 | **ok** `\($0)` |\n" }
        run("80-row table", flushes: Self.flushes(streaming: "Totals so far:\n\n" + header + rows.joined()))
    }

    @Test("A table wider than the screen, streamed")
    func wideTable() {
        let columns = 14
        let header = "|" + (0..<columns).map { " column \($0) |" }.joined() + "\n|" + String(repeating: " --- |", count: columns) + "\n"
        let rows = (0..<40).map { row in "|" + (0..<columns).map { " value \(row)-\($0) |" }.joined() + "\n" }
        run("14-column table", flushes: Self.flushes(streaming: header + rows.joined()))
    }

    @Test("A short reply in a chat bubble, streamed")
    func shortReply() {
        run("short reply", flushes: Self.flushes(streaming: TestDocuments.everything.markdown), bubble: true)
    }

    @Test("A finished transcript laid out again at another width")
    func relayout() {
        let markdown = String(repeating: TestDocuments.everything.markdown + "\n\n" + TestDocuments.tables.markdown + "\n\n", count: 4)
        let blocks = IncrementalMarkdownParser.blocks(parsing: markdown)
        let host = Host(blocks: blocks, probe: nil, bubble: false)
        host.layout()
        Self.announceForProfiler()

        var durations: [Duration] = []
        for index in 0..<200 {
            host.window.frame.size.width = index.isMultiple(of: 2) ? 320 : 402
            durations.append(clock.measure { host.layout() })
        }

        let probe = MeasureProbe()
        let counted = Host(blocks: blocks, probe: probe, bubble: false)
        counted.layout()
        let before = probe.sizeQueries
        for index in 0..<10 {
            counted.window.frame.size.width = index.isMultiple(of: 2) ? 320 : 402
            counted.layout()
        }
        let perRelayout = Double(probe.sizeQueries - before) / 10
        print("BENCHMARK relayout of \(blocks.count) settled blocks at a new width: \(Stats(durations)); block size queries \(String(format: "%.1f", perRelayout))/relayout")
    }

    // MARK: Scenario runner

    private let clock = ContinuousClock()

    /// Times every flush, then replays the same flushes with the counting
    /// probe installed, so the probe's own cost stays out of the timings.
    private func run(_ name: String, flushes: [[MarkdownBlock]], bubble: Bool = false) {
        Host(blocks: flushes.last ?? [], probe: nil, bubble: bubble).layout()
        Self.announceForProfiler()

        let timed = Host(blocks: [], probe: nil, bubble: bubble)
        var durations: [Duration] = []
        for blocks in flushes {
            durations.append(clock.measure { timed.update(blocks) })
        }

        let probe = MeasureProbe()
        let counted = Host(blocks: [], probe: probe, bubble: bubble)
        for blocks in flushes { counted.update(blocks) }

        let perFlush = Double(probe.sizeQueries) / Double(max(1, flushes.count))
        print("BENCHMARK \(name), \(flushes.count) flushes, \(flushes.last?.count ?? 0) blocks: \(Stats(durations)); block size queries \(probe.sizeQueries) (\(String(format: "%.1f", perFlush))/flush), placements \(probe.placements)")
    }

    /// With `MARKDOWN_BENCHMARK_PID_FILE` set, writes this process's id there,
    /// so a sampling profiler on the host (`sample <pid>`) can attach to the
    /// scenario that follows.
    private static func announceForProfiler() {
        guard let path = ProcessInfo.processInfo.environment["MARKDOWN_BENCHMARK_PID_FILE"] else { return }
        try? String(ProcessInfo.processInfo.processIdentifier).write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// The blocks after each flush of a stream: four-character tokens,
    /// flushed six at a time, about what a 30 Hz coalescing client sees.
    private static func flushes(streaming markdown: String) -> [[MarkdownBlock]] {
        var state = IncrementalParseState()
        var result: [[MarkdownBlock]] = []
        for (index, token) in markdown.chunked(by: 4).enumerated() {
            state.append(token)
            if index % 6 == 5 { result.append(state.blocks) }
        }
        result.append(state.finish().blocks)
        return result
    }
}

// MARK: - Hosting

/// A message hosted in a window, as in an app: inside a vertical scroll view,
/// optionally in a bubble that hugs its content.
@MainActor
private final class Host {

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    private let controller: UIHostingController<Harness>
    private let probe: MeasureProbe?
    private let bubble: Bool

    init(blocks: [MarkdownBlock], probe: MeasureProbe?, bubble: Bool) {
        self.probe = probe
        self.bubble = bubble
        controller = UIHostingController(rootView: Harness(blocks: blocks, probe: probe, bubble: bubble))
        window.rootViewController = controller
        window.isHidden = false
    }

    func update(_ blocks: [MarkdownBlock]) {
        controller.rootView = Harness(blocks: blocks, probe: probe, bubble: bubble)
        layout()
    }

    func layout() {
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
}

private struct Harness: View {
    let blocks: [MarkdownBlock]
    let probe: MeasureProbe?
    let bubble: Bool

    var body: some View {
        ScrollView {
            if bubble {
                HStack {
                    message
                        .padding(12)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 16)
            } else {
                message
                    .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var message: some View {
        if let probe {
            MarkdownMessageView(blocks: blocks) { block in
                CountingLayout(probe: probe) { MarkdownBlockView(block: block) }
            }
        } else {
            MarkdownMessageView(blocks: blocks)
        }
    }
}

// MARK: - Counting

final class MeasureProbe: @unchecked Sendable {
    var sizeQueries = 0
    var placements = 0
}

/// Passes layout straight through to its one subview, counting the calls.
private struct CountingLayout: Layout {
    let probe: MeasureProbe

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        probe.sizeQueries += 1
        return subviews.first?.sizeThatFits(proposal) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        probe.placements += 1
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - Statistics

private struct Stats: CustomStringConvertible {
    let milliseconds: [Double]

    init(_ durations: [Duration]) {
        milliseconds = durations.map {
            Double($0.components.seconds) * 1000 + Double($0.components.attoseconds) / 1e15
        }.sorted()
    }

    var description: String {
        guard !milliseconds.isEmpty else { return "no samples" }
        let total = milliseconds.reduce(0, +)
        return String(
            format: "total %.1f ms, mean %.2f, p50 %.2f, p95 %.2f, max %.2f ms",
            total,
            total / Double(milliseconds.count),
            percentile(0.5),
            percentile(0.95),
            milliseconds.last ?? 0
        )
    }

    private func percentile(_ fraction: Double) -> Double {
        milliseconds[min(milliseconds.count - 1, Int(Double(milliseconds.count - 1) * fraction))]
    }
}
