import Foundation

/// One document that exercises every block kind and, more importantly, every
/// way a chunk boundary can land in the middle of markdown syntax.
enum SampleMarkdown {

    static let document = """
    # Streaming markdown in SwiftUI

    Short answer: **parse at the block level, render at the frame rate.** Those \
    are two separate problems, and conflating them is what makes streaming \
    markdown feel janky.

    ## Why the obvious approach falls apart

    Re-parsing the whole response on every token works for a paragraph or two. Then:

    - it is *O(n²)* over the response — the 900th token re-parses 900 tokens' worth of text
    - every view in the message is invalidated on every token
    - half-arrived syntax leaks: you watch `**bo` sit on screen as literal asterisks
    - a half-typed [link](https://developer.apple.com/documentation/swiftui) shows its raw URL

    > The fix is not a faster parser. It is parsing less: while a response
    > streams, only the final block can still change.

    ## The shape that works

    1. Split the incoming text into **blocks** — headings, paragraphs, lists, quotes, tables
    2. Treat every block but the last as immutable and never look at it again
    3. Re-parse only the open tail, and balance its dangling `**`, `_`, `~~` and backticks
    4. Hand SwiftUI `Equatable` values so settled blocks are skipped outright

    ## What each piece buys you

    | Technique | Fixes | Cost |
    | --- | --- | :---: |
    | Windowed parsing | `O(n²)` re-parsing | ~150 lines |
    | Delimiter balancing | `**` flashing on screen | ~60 lines |
    | Table completion | a paragraph of pipes | ~80 lines |

    ## Things that bite

    - [x] Chunks split mid-word, mid-`**` and mid-table-row
    - [x] A table row that arrives as `| ` must not settle as a paragraph before it rejoins the table
    - [x] Identifiers like `max_tokens` and `snake_case_name` must survive emphasis repair
    - [ ] Nested blockquotes and setext headings — skipped here on purpose

    ---

    One more thing: this ~~was~~ is the whole pipeline. Fenced code is shown as \
    plain text rather than dropped:

    ```swift
    let snapshot = await parser.append(chunk)
    ```
    """

    /// Splits text into pieces about the size of real model tokens: short, cut
    /// at word boundaries where convenient, with newlines delivered on their own.
    static func tokens(of text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if character == "\n" {
                tokens.append(current)
                current = ""
            } else if current.count >= 3, character == " " {
                tokens.append(current)
                current = ""
            } else if current.count >= 6 {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
