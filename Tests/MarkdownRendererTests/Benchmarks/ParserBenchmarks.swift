import Foundation
import Markdown
import Testing
@testable import MarkdownRenderer

/// Timings for each stage of a parse, printed rather than asserted: wall
/// time is too noisy to fail a build on. Algorithmic cost is asserted by the
/// regular tests instead, through `ParseMetrics.charactersScanned`.
///
/// Off by default. Run them in Release, where the numbers mean something:
///
///     test_sim  -only-testing:MarkdownRendererTests/ParserBenchmarks
///               -configuration Release ENABLE_TESTABILITY=YES
///               testRunnerEnv: MARKDOWN_BENCHMARKS=1
///
/// and read the `BENCHMARK` lines from the log.
@Suite("ParserBenchmarks", .enabled(if: ProcessInfo.processInfo.environment["MARKDOWN_BENCHMARKS"] != nil))
struct ParserBenchmarks {

    private let clock = ContinuousClock()

    @Test("Per-stage cost of one flush over a 10 KB open block")
    func stages() {
        let inlineHeavy = String(repeating: "lorem **ipsum** [x](y) ", count: 450)
        let longTable = "| a | b | c |\n| --- | --- | --- |\n" + String(repeating: "| one **two** | `three` | four |\n", count: 300)
        let repetitions = 200

        for (name, window) in [("inline-heavy paragraph", inlineHeavy), ("300-row table", longTable)] {
            let scan = WindowScan(window)
            let document = Document(parsing: window)
            let timings = [
                ("scan", measure(repetitions) { WindowScan(window).linesAfterBlankLine.count }),
                ("repairs", measure(repetitions) { ProvisionalSource.make(from: window, scan: scan, repairs: .all).utf8.count }),
                ("cmark", measure(repetitions) { Document(parsing: window).childCount }),
                ("convert", measure(repetitions) { MarkdownDocumentConverter.blocks(of: document).count }),
            ]
            let summary = timings.map { "\($0.0)=\($0.1)µs" }.joined(separator: " ")
            print("BENCHMARK \(name), \(window.utf8.count) B, per flush: \(summary)")
        }
    }

    @Test("A realistic reply streamed token by token")
    func realisticReply() {
        let reply = String(repeating: TestDocuments.everything.markdown + "\n\n" + TestDocuments.tables.markdown + "\n\n", count: 10)
        let tokens = reply.chunked(by: 4)
        var metrics = ParseMetrics()
        let total = clock.measure {
            var state = IncrementalParseState()
            for token in tokens { state.append(token) }
            metrics = state.finish().metrics
        }
        print("BENCHMARK reply of \(reply.utf8.count) B in \(tokens.count) tokens: \(total) total, \(metrics.charactersScanned) characters scanned")
    }

    @Test("One long paragraph, the worst case for block-level windowing")
    func longParagraph() {
        let total = clock.measure {
            var state = IncrementalParseState()
            for _ in 0..<3500 { state.append("lorem ") }
            state.finish()
        }
        print("BENCHMARK one paragraph of 21 KB in 3500 appends: \(total)")
    }

    /// Microseconds per run of `work`, whose result is kept so the optimizer
    /// cannot drop it.
    private func measure(_ repetitions: Int, _ work: () -> Int) -> Int {
        var sink = 0
        let duration = clock.measure {
            for _ in 0..<repetitions { sink &+= work() }
        }
        withExtendedLifetime(sink) {}
        let microseconds = Double(duration.components.seconds) * 1e6 + Double(duration.components.attoseconds) / 1e12
        return Int(microseconds / Double(repetitions))
    }
}
