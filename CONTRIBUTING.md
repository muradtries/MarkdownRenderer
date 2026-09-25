# Contributing to MarkdownRenderer

This guide is the map of the package: what each part does, the rules the code keeps, and how to change it safely. Read it once before your first change; after that, the "Recipes" section is usually all you need.

## The package in one paragraph

A language model sends text in small chunks. `IncrementalMarkdownParser` turns those chunks into a list of `MarkdownBlock` values (heading, paragraph, list, quote, table, divider) and hands them to `MarkdownMessageView`, which draws each block with a style the app can replace. Two ideas make it fast: only the **last few blocks** are ever re-parsed, because everything before them can no longer change; and a block that did not change is **never redrawn**, because blocks are compared by value before SwiftUI runs their body.

## Source map

```
Sources/MarkdownRenderer/
├── Model/                         Plain values. No SwiftUI, no parsing.
│   ├── MarkdownBlock.swift        A block: id (its position), kind, isFinal, arrivals
│   ├── MarkdownListItem.swift     One flattened list item
│   ├── MarkdownTable.swift        Header, alignments, rows
│   └── TextArrival.swift          When a stretch of text arrived, for the fade-in
│
├── Parsing/                       Text in, blocks out. No SwiftUI.
│   ├── IncrementalMarkdownParser.swift   The public actor: a thin shell over the state
│   ├── IncrementalParseState.swift       The state machine: window, settling, ids
│   ├── MarkdownStreamingOptions.swift    Which repairs run, arrival settings, the clock
│   ├── ParseMetrics.swift                What a stream has cost so far
│   ├── ArrivalTracker.swift              Stamps arrivals onto the open blocks
│   ├── Window/
│   │   ├── LineEndingNormalizer.swift    \r\n and \r to \n, across chunk boundaries
│   │   └── WindowScan.swift              Blank lines, fences, where repairs may start
│   ├── Repair/                           Make an unfinished tail presentable
│   │   ├── ProvisionalSource.swift       Runs the repairs below, in order
│   │   ├── MarkerWithholding.swift       Hide a line that is only "-", "##", "1."…
│   │   ├── IncompleteLinkRepair.swift    "[docs](http" → "docs"
│   │   ├── InlineDelimiterRepair.swift   "**bo" → "**bo**"
│   │   └── TableCompletion.swift         Synthesise a table's delimiter row
│   ├── Conversion/                       swift-markdown AST → blocks
│   │   ├── MarkdownDocumentConverter.swift   Block level
│   │   └── InlineTextConverter.swift         Inline level → AttributedString
│   └── Text/UTF8Text.swift               Byte-level helpers the scanners share
│
├── Rendering/                     Blocks in, views out.
│   ├── MarkdownMessageView.swift  The list of blocks; diffing; one-shot parsing
│   ├── MarkdownBlockView.swift    One block → the style installed for its kind
│   ├── MarkdownText.swift         Inline text with code background, link underline, fade-in
│   └── FadeIn/
│       ├── FadeCurve.swift        The fade as plain arithmetic (tested without views)
│       ├── FadeSchedule.swift     TimelineView frames until the fade is done
│       └── StreamingText.swift    Text + TextRenderer (iOS 18), plain Text below
│
└── Styling/                       What the app can customise.
    ├── MarkdownTheme.swift        Values: fonts, spacing, colours, fade timing
    └── Markdown…Style.swift       One file per block kind: protocol, configuration,
                                   default style, view modifier, type eraser
```

Tests mirror this layout under `Tests/MarkdownRendererTests/`, plus `Support/` (shared fixtures and checks) and `Benchmarks/`.

## The life of one `append`

`IncrementalParseState.append(_:)` is the heart of the package. In order:

1. **Normalize line endings** (`LineEndingNormalizer`). A `\r` at the end of a chunk is held back until the next chunk shows whether a `\n` follows.
2. **Add the chunk to the window.** The window is the source text of the blocks that can still change.
3. **Scan the window** (`WindowScan`): which lines follow a blank line, where the last blank line or closing fence is, and whether the window ends inside a code fence.
4. **Build the provisional source** (`ProvisionalSource`): the window with its unfinished end repaired. Skipped by `finish()`.
5. **Parse** with swift-markdown and **convert** the AST to block kinds (`MarkdownDocumentConverter`, `InlineTextConverter`).
6. **Replace the open blocks.** The blocks previously parsed from the window are removed and the new ones appended, with ids that continue from the settled blocks.
7. **Stamp arrivals** (`ArrivalTracker`) onto the open blocks.
8. **Settle.** Every block before the last one that starts right after a blank line is marked final, and its source is dropped from the window. It is never looked at again.

`finish()` repeats steps 3, 5, 6 and 7 without repairs and marks everything final.

## Rules the code keeps

These are the promises the rest of the package — and every app using it — relies on. Each is enforced by a test; if you break one, a test tells you which.

| Rule | Why it matters | Enforced by |
|---|---|---|
| A block's id is its position, and ids never change. | SwiftUI keeps view identity, `@State` and selection. | `StreamingInvariants` |
| Once a block is final, it never changes again — not even its arrivals. | Settled blocks compare equal and are never redrawn. | `StreamingInvariants` |
| Final blocks form a prefix of the list. | Only the tail is ever re-parsed. | `StreamingInvariants` |
| Streaming a text in any chunks, then calling `finish()`, gives the same blocks as parsing it in one go. | Chunking decides *when* text appears, never *what*. | `StreamingFuzzTests`, `IncrementalParseStateTests` |
| Repairs never change the finished document. | They are presentation only. | `StreamingFuzzTests` |
| Nothing inside an open code fence is repaired or split. | Code is literal. | `ProvisionalSourceTests`, `IncrementalParseStateTests` |
| Arrivals are sorted, distinct and inside the block's text; tables and dividers have none. | The fade-in draws the right characters. | `StreamingInvariants` |
| The cost of a flush follows the size of the window, not of the response. | Long replies stay smooth. | `charactersScanned` tests |

## Recipes

### Add a streaming repair

1. Write it as an `enum` in `Parsing/Repair/` with one `static func apply(to tail: String) -> String`. It gets only the text after the last blank line or closing fence, never the inside of an open fence.
2. Scan UTF-8 bytes (`UTF8Text`), not `Character`s: markdown syntax is ASCII, and byte scans are several times faster.
3. Add an option to `MarkdownStreamingOptions.Repairs` and include it in `.all`.
4. Call it from `ProvisionalSource.make` at the right point in the order, and document why it goes there.
5. Test it on its own with a table of `(input, expected)` cases, and add a streaming case to `IncrementalParseStateTests`. If it has a tricky boundary, add a document to `TestDocuments` so the fuzz tests cover it.

### Add a block kind

1. Add the case to `MarkdownBlock.Kind` with a doc comment.
2. Map the swift-markdown node to it in `MarkdownDocumentConverter.kind(of:)`.
3. Decide whether it fades in: update `fadeableLength` in `ArrivalTracker.swift`.
4. Add `Styling/Markdown<Kind>Style.swift` by copying the paragraph style file: protocol, configuration (with an internal `init`), default style, `markdown<Kind>Style(_:)` modifier, type eraser, environment entry.
5. Add the case to `MarkdownBlockView.body`.
6. Add any values its default style needs to `MarkdownTheme`, in the matching `// MARK:` section.
7. Test the conversion, the configuration, and add the kind to `TestDocuments.everything`.
8. Update the README's feature list.

### Add a theme value

Add a `public var` with a default and a `///` comment to the right section of `MarkdownTheme`, read it from the default style that needs it. Never read the environment inside a style: styles get the theme from their configuration.

### Change how text fades in

The arithmetic lives in `FadeCurve` and is tested in `FadeCurveTests`; `StreamingText.swift` only draws. If the fade gets longer, make sure `MarkdownStreamingOptions.arrivalRetention` still covers it — `MarkdownThemeTests` checks the defaults.

## Tests

The package uses [Swift Testing](https://developer.apple.com/documentation/testing).

- **Test the smallest piece that owns the behaviour.** A repair rule is tested on the repair, not through the parser. The parser tests use `IncrementalParseState` synchronously; only `IncrementalMarkdownParserTests` goes through the actor.
- **Stream through `StreamingInvariants.stream(_:)`.** It checks every rule in the table above after every chunk, so a streaming test gets them all for free.
- **Add tricky input to `TestDocuments`.** Every document there is streamed in fixed and random chunkings and compared with a one-shot parse.
- **Random, but reproducible.** The fuzz tests use `SeededGenerator`; a failure message names the seed, and the same seed gives the same chunks.
- **Time is injected.** Use `TestClock` with `MarkdownStreamingOptions(now:)`, and advance it by values that are exact in binary (`0.25`, `0.125`) so expected times compare equal.
- **Performance is asserted by counting, not timing.** Tests check `charactersScanned`; wall-clock numbers come from the opt-in benchmarks.

### Running

With [XcodeBuildMCP](https://xcodebuildmcp.com), using the package's own workspace:

```
test_sim   workspacePath: .swiftpm/xcode/package.xcworkspace   scheme: MarkdownRenderer
```

Or with `xcodebuild`:

```sh
xcodebuild test -scheme MarkdownRenderer -destination 'platform=iOS Simulator,name=iPhone 16'
```

Benchmarks are skipped unless `MARKDOWN_BENCHMARKS` is set, and only mean something in Release:

```sh
TEST_RUNNER_MARKDOWN_BENCHMARKS=1 xcodebuild test -scheme MarkdownRenderer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Release ENABLE_TESTABILITY=YES \
  -only-testing:MarkdownRendererTests/ParserBenchmarks
```

Look for lines starting with `BENCHMARK` in the output. Run them before and after a change to the parser, and put the numbers in the pull request.

## Conventions

- **Comments.** Every declaration that is not obvious gets a `///` comment saying *why* it exists or what it guarantees. There are no `//` comments inside function bodies: if a line needs explaining, give it a better name or move it into a small, documented helper. `// MARK:` separates sections.
- **Values over objects.** Models, the parse state and style configurations are structs. The only reference type is the actor.
- **The model knows no fonts.** Blocks carry semantic attributes (`inlinePresentationIntent`, `link`); fonts and colours come from the theme at render time.
- **Never rebuild a settled block.** Its `AttributedString` storage is shared from flush to flush, which is what makes comparing it O(1).
- **Every public symbol is documented** and appears in the DocC catalog under `Sources/MarkdownRenderer/MarkdownRenderer.docc`.
- **Swift 6 strict concurrency.** Everything that crosses an actor is `Sendable`.
