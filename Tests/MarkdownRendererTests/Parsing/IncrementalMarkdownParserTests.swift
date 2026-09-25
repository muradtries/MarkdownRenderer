import Foundation
import Testing
@testable import MarkdownRenderer

/// The actor is a thin shell around ``IncrementalParseState``; these tests
/// cover the shell. Streaming behaviour is tested on the state directly.
@Suite("IncrementalMarkdownParser")
struct IncrementalMarkdownParserTests {

    @Test("append and finish return the state's snapshots across the actor boundary")
    func appendAndFinish() async {
        let parser = IncrementalMarkdownParser()
        let partial = await parser.append("# Hi\n\nthere")
        #expect(partial.blocks.map(\.isFinal) == [true, false])
        #expect(await parser.snapshot == partial)
        #expect(await parser.blocks == partial.blocks)
        #expect(await parser.rawText == "# Hi\n\nthere")

        let finished = await parser.finish()
        #expect(finished.blocks.allSatisfy { $0.isFinal })
        #expect(await parser.metrics == finished.metrics)
    }

    @Test("reset starts over with the same options")
    func reset() async {
        let parser = IncrementalMarkdownParser(options: MarkdownStreamingOptions(repairs: []))
        await parser.append("the **impor")
        await parser.reset()
        #expect(await parser.blocks.isEmpty)

        let snapshot = await parser.append("the **impor")
        guard case .paragraph(let text) = snapshot.blocks.last?.kind else {
            Issue.record("expected a paragraph")
            return
        }
        #expect(String(text.characters) == "the **impor")
    }

    @Test("Parsers are independent actors, so streams parse side by side")
    func concurrentStreams() async {
        let documents = TestDocuments.all
        let results = await withTaskGroup(of: (String, [MarkdownBlock.Kind]).self) { group in
            for document in documents {
                group.addTask {
                    let parser = IncrementalMarkdownParser()
                    for chunk in document.markdown.chunked(by: 5) {
                        await parser.append(chunk)
                    }
                    return (document.name, await parser.finish().blocks.map(\.kind))
                }
            }
            var results: [String: [MarkdownBlock.Kind]] = [:]
            for await (name, kinds) in group {
                results[name] = kinds
            }
            return results
        }
        for document in documents {
            #expect(results[document.name] == IncrementalMarkdownParser.blocks(parsing: document.markdown).map(\.kind))
        }
    }

    @Test("One-shot parsing is a single full parse, so a link can use a definition that comes later")
    func oneShotResolvesLaterDefinitions() {
        let blocks = IncrementalMarkdownParser.blocks(parsing: "See [the docs][docs].\n\n[docs]: https://example.com")
        guard case .paragraph(let text) = blocks.first?.kind else {
            Issue.record("expected a paragraph")
            return
        }
        #expect(text.runs.contains { $0.link == URL(string: "https://example.com") })
        #expect(blocks.allSatisfy { $0.isFinal })
        #expect(blocks.map(\.id) == Array(blocks.indices))
    }
}
