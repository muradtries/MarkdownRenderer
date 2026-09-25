import Testing
@testable import MarkdownRenderer

@Suite("WindowScan")
struct WindowScanTests {

    @Test("Repairs start after the last blank line")
    func repairStartAfterBlankLine() {
        let source = "one\n\ntwo\n\nthree"
        #expect(tail(of: source) == "three")
        #expect(tail(of: "no boundary") == "no boundary")
        #expect(tail(of: "trailing\n\n") == "")
        #expect(tail(of: "spaces only\n   \nafter") == "after")
    }

    @Test("Repairs start after the last closing fence")
    func repairStartAfterClosedFence() {
        #expect(tail(of: "~~~\n**x\n~~~\nSome") == "Some")
        #expect(tail(of: "a\n\n```\ncode\n```\n\nb **c") == "b **c")
    }

    @Test("Lines after a blank line are block starts that nothing earlier can absorb")
    func linesAfterBlankLine() {
        #expect(WindowScan("a\n\nb\nc\n\n\nd").linesAfterBlankLine == [3, 7])
        #expect(WindowScan("a\nb").linesAfterBlankLine == [])
        #expect(WindowScan("a\n\n").linesAfterBlankLine == [])
    }

    @Test("Blank lines inside a fence are not boundaries")
    func blankLinesInsideFence() {
        let scan = WindowScan("intro\n\n```\none\n\ntwo\n```\n\nafter")
        #expect(scan.linesAfterBlankLine == [3, 9])
        #expect(scan.openFence == nil)
    }

    @Test("The window can end inside a fence", arguments: [
        ("```\ncode", "`", 3),
        ("~~~~\ncode", "~", 4),
        ("text\n\n  ```swift\ncode\n\nmore", "`", 3),
        ("````\n```\ninner\n```", "`", 4),
        ("```\n```python\nstill code", "`", 3),
    ])
    func endsInsideFence(source: String, marker: String, length: Int) throws {
        let fence = try #require(WindowScan(source).openFence)
        #expect(fence == WindowScan.Fence(marker: UInt8(ascii: Unicode.Scalar(marker)!), length: length))
    }

    @Test("A fence closes only with the same marker, at least as long, and nothing after it", arguments: [
        "```\ncode\n```",
        "```\ncode\n````",
        "```\ncode\n```   ",
        "~~~\n```\n~~~",
        "````\n```\n````",
    ])
    func closedFence(source: String) {
        #expect(WindowScan(source).openFence == nil)
    }

    @Test("A backtick run with backticks after it is inline code, not a fence")
    func inlineCodeIsNotAFence() {
        #expect(WindowScan("```inline``` text").openFence == nil)
        #expect(WindowScan("~~~ has ` backtick\ncode").openFence != nil)
    }

    private func tail(of source: String) -> Substring {
        source[WindowScan(source).repairStart...]
    }
}

@Suite("LineEndingNormalizer")
struct LineEndingNormalizerTests {

    @Test("Chunks are normalized, holding back a trailing carriage return", arguments: [
        (["a\r\nb"], "a\nb"),
        (["a\rb"], "a\nb"),
        (["a\r", "\nb"], "a\nb"),
        (["a\r", "b"], "a\nb"),
        (["a\r", "\r\nb"], "a\n\nb"),
        (["a\r", "", "\nb"], "a\nb"),
        (["a\r"], "a\n"),
        (["plain"], "plain"),
    ])
    func normalizesAcrossChunks(chunks: [String], expected: String) {
        var normalizer = LineEndingNormalizer()
        let output = chunks.map { normalizer.normalize($0) }.joined() + normalizer.flush()
        #expect(output == expected)
    }

    @Test("flush releases a held carriage return once")
    func flushOnce() {
        var normalizer = LineEndingNormalizer()
        #expect(normalizer.normalize("x\r") == "x")
        #expect(normalizer.flush() == "\n")
        #expect(normalizer.flush() == "")
    }
}
