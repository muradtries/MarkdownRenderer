import Foundation
import Testing
@testable import MarkdownRenderer

/// Random chunk boundaries, reproducible from a seed. Every flush is held to
/// ``StreamingInvariants``, and the finished stream must equal the one-shot
/// parse: chunking changes when text appears, never what appears.
@Suite("Streaming fuzz")
struct StreamingFuzzTests {

    @Test("Random chunkings keep every invariant and finish equal to one-shot parsing", arguments: TestDocuments.all)
    func randomChunkings(document: TestDocument) {
        let expected = IncrementalMarkdownParser.blocks(parsing: document.markdown).map(\.kind)
        for seed in UInt64(1)...40 {
            var generator = SeededGenerator(seed: seed)
            let chunks = document.markdown.randomlyChunked(using: &generator)
            let streamed = StreamingInvariants.stream(chunks, context: "\(document.name), seed \(seed)")
            #expect(streamed.map(\.kind) == expected, "\(document.name), seed \(seed)")
        }
    }

    @Test("Without repairs the finished stream is unchanged", arguments: TestDocuments.all)
    func repairsNeverChangeTheResult(document: TestDocument) {
        let expected = IncrementalMarkdownParser.blocks(parsing: document.markdown).map(\.kind)
        var generator = SeededGenerator(seed: 7)
        let chunks = document.markdown.randomlyChunked(using: &generator)
        let streamed = StreamingInvariants.stream(chunks, options: MarkdownStreamingOptions(repairs: []), context: document.name)
        #expect(streamed.map(\.kind) == expected)
    }

    @Test("Windows line endings with random boundaries finish like Unix ones", arguments: TestDocuments.all)
    func randomWindowsLineEndings(document: TestDocument) {
        let expected = IncrementalMarkdownParser.blocks(parsing: document.markdown).map(\.kind)
        let windows = document.markdown.replacingOccurrences(of: "\n", with: "\r\n")
        for seed in UInt64(1)...10 {
            var generator = SeededGenerator(seed: seed)
            let chunks = windows.randomlyChunked(using: &generator)
            let streamed = StreamingInvariants.stream(chunks, context: "\(document.name) CRLF, seed \(seed)")
            #expect(streamed.map(\.kind) == expected, "\(document.name) CRLF, seed \(seed)")
        }
    }
}
