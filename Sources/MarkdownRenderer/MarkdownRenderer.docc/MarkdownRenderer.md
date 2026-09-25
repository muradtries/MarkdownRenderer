# ``MarkdownRenderer``

Render markdown that arrives one token at a time.

## Overview

Feed ``IncrementalMarkdownParser`` the chunks of a streaming response and hand the blocks it returns to ``MarkdownMessageView``. Half-arrived syntax is repaired before it reaches the screen, only the block still being written is re-parsed, and only that block is redrawn.

```swift
let parser = IncrementalMarkdownParser()
for try await chunk in stream {
    message.blocks = await parser.append(chunk).blocks
}
message.blocks = await parser.finish().blocks
```

```swift
MarkdownMessageView(blocks: message.blocks)
    .markdownTheme(theme)
```

Appearance is customised in three layers: values in a ``MarkdownTheme``, the layout of one block kind with a style such as ``MarkdownTableStyle``, and any view per block through the content builder of ``MarkdownMessageView``.

## Topics

### Parsing a stream

- ``IncrementalMarkdownParser``
- ``IncrementalParseState``
- ``MarkdownStreamingOptions``
- ``ParseMetrics``

### The block model

- ``MarkdownBlock``
- ``MarkdownListItem``
- ``MarkdownTable``
- ``TextArrival``

### Rendering

- ``MarkdownMessageView``
- ``MarkdownBlockView``
- ``MarkdownText``

### Theme

- ``MarkdownTheme``

### Heading style

- ``MarkdownHeadingStyle``
- ``MarkdownHeadingStyleConfiguration``
- ``DefaultMarkdownHeadingStyle``

### Paragraph style

- ``MarkdownParagraphStyle``
- ``MarkdownParagraphStyleConfiguration``
- ``DefaultMarkdownParagraphStyle``

### List style

- ``MarkdownListStyle``
- ``MarkdownListStyleConfiguration``
- ``DefaultMarkdownListStyle``

### Quote style

- ``MarkdownQuoteStyle``
- ``MarkdownQuoteStyleConfiguration``
- ``DefaultMarkdownQuoteStyle``

### Table style

- ``MarkdownTableStyle``
- ``MarkdownTableStyleConfiguration``
- ``DefaultMarkdownTableStyle``

### Divider style

- ``MarkdownDividerStyle``
- ``MarkdownDividerStyleConfiguration``
- ``DefaultMarkdownDividerStyle``
