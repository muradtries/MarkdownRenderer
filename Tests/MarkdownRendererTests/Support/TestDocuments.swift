import Foundation
import Testing

struct TestDocument: CustomTestStringConvertible, Sendable {
    let name: String
    let markdown: String

    var testDescription: String { name }
}

/// Documents that between them cover every block kind and every place a chunk
/// boundary can fall inside markdown syntax. Streaming tests run over all of
/// them, so a new tricky case belongs here.
enum TestDocuments {

    static let all = [everything, tables, fences, listsAndQuotes, nestedFences, looseLists, unicode]

    static let everything = TestDocument(name: "everything", markdown: """
    # Title

    A paragraph with **bold**, *italic*, `code`, ~~gone~~ and a [link](https://example.com).

    - one
    - two
      - nested
    1. first
    2. second

    - loose item

      with a continuation paragraph

    - second loose item

    > quoted
    > across lines

    ```swift
    let x = 1
    ```

    | a | b |
    | --- | ---: |
    | 1 | 2 |

    ---

    The end.
    """)

    static let tables = TestDocument(name: "tables", markdown: """
    ## Pacing, measured

    | Pacing | Renders / sec | Feels like |
    | --- | ---: | --- |
    | `.immediate` | 60–400 | lurching on bursty gateways |
    | `.coalesced(33ms)` | 30 | matches the network |

    Prose between tables with **strong** text.

    | Case | Handled by |
    | :---: | --- |
    | Consumer cancelled | `onTermination` |
    | Upstream throws | `finish(error:)` |
    """)

    static let fences = TestDocument(name: "fences", markdown: """
    Intro **bold** line.

    ```
    a ** b `c

    still inside * the fence
    ```

    ~~~
    tilde fence with | pipes | and - dashes
    ~~~

    After the fences, an _emphasised_ word and snake_case_name.
    """)

    static let listsAndQuotes = TestDocument(name: "lists and quotes", markdown: """
    Things that bite:

    - [x] Chunks split mid-word, mid-`**` and mid-table-row
    - [x] Identifiers like `max_tokens` survive emphasis repair
    - [ ] Nested blockquotes — skipped here on purpose

    3. starts at three
    4. then four
       1. nested ordered
    5. five

    > The fix is not a faster parser.
    > It is parsing less.

    > A second quote with **strong** and `code`.

    * * *

    Done ~~for now~~ for good.
    """)

    static let nestedFences = TestDocument(name: "nested fences", markdown: """
    A README inside an answer:

    ````markdown
    # Inner title

    ```swift
    let x = **1**
    ```

    ```bash info
    ````

    1. Install it:

       ```sh
       swift build

       swift test
       ```

    2. Done.
    """)

    static let looseLists = TestDocument(name: "loose lists", markdown: """
    Before the list, a paragraph with **bold** text.

    - first item

    - second item, loose

      with a continuation

    - third item

    After the list.
    """)

    static let unicode = TestDocument(name: "unicode", markdown: """
    # Café 👨‍👩‍👧 e\u{301}clair

    **flag 🇺🇸** and _наклон_ and `コード`.

    | 名前 | 値 |
    | --- | --- |
    | ✓ | 🚀 |
    """)
}

extension String {
    /// Splits into chunks of `size` characters; the last one may be shorter.
    func chunked(by size: Int) -> [String] {
        var chunks: [String] = []
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[index..<next]))
            index = next
        }
        return chunks
    }

    /// Splits at random UTF-8 offsets, including inside multi-byte scalars'
    /// neighbours but never inside a scalar, so every chunk is valid text.
    func randomlyChunked(using generator: inout some RandomNumberGenerator, maxSize: Int = 12) -> [String] {
        let scalars = Array(unicodeScalars)
        var chunks: [String] = []
        var start = 0
        while start < scalars.count {
            let end = min(scalars.count, start + Int.random(in: 1...maxSize, using: &generator))
            var chunk = ""
            chunk.unicodeScalars.append(contentsOf: scalars[start..<end])
            chunks.append(chunk)
            start = end
        }
        return chunks
    }
}

/// A small deterministic generator, so a failing random chunking can be
/// reproduced from its seed.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A clock a test moves by hand.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: TimeInterval

    init(_ start: TimeInterval = 1000) {
        current = start
    }

    var now: TimeInterval {
        lock.withLock { current }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { current += seconds }
    }
}
