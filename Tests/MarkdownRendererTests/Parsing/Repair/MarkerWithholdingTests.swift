import Testing
@testable import MarkdownRenderer

@Suite("MarkerWithholding")
struct MarkerWithholdingTests {

    @Test("Marker-only lines", arguments: [
        "#", "######", "-", "*", "+", ">", ">>", "> >", "|", "`", "``", "```", "~", "~~~",
        "1", "123456789", "1.", "1)", "12.", "  -  ", "> -", "> 1.", "- >",
        "- [", "- [x", "- [X", "- [ ]", "- [x]", "* [X]", "+ [", "1. [ ]", "> - [x",
    ])
    func markerOnly(line: String) {
        #expect(MarkerWithholding.isMarkerOnly(Substring(line).utf8), "\(line)")
    }

    @Test("Lines with content", arguments: [
        "", "   ", "word", "#hash", "# title", "- x", "1. x", "1.5", "1234567890", "12a",
        "---", "***", "___", "- - -", "* * *", "_ _ _", "> ---",
        "[x]", "[", "- [x] done", "- [ab", "- [xy]", "|a", "`code`",
    ])
    func hasContent(line: String) {
        #expect(!MarkerWithholding.isMarkerOnly(Substring(line).utf8), "\(line)")
    }

    @Test("Only an unfinished last line is withheld", arguments: [
        ("intro\n-", "intro\n"),
        ("intro\n-\n", "intro\n-\n"),
        ("-", ""),
        ("intro\n- x", "intro\n- x"),
        ("", ""),
    ])
    func withholdsLastLine(input: String, expected: String) {
        #expect(MarkerWithholding.apply(to: input) == expected)
    }

    @Test("Inside a fence only a partial closing fence is withheld", arguments: [
        ("```\ncode\n``", "```\ncode\n"),
        ("```\ncode\n  `", "```\ncode\n"),
        ("```\ncode\n#", "```\ncode\n#"),
        ("```\ncode\n-", "```\ncode\n-"),
        ("```\ncode\n~~", "```\ncode\n~~"),
        ("```\ncode\n", "```\ncode\n"),
    ])
    func partialClosingFence(input: String, expected: String) {
        let fence = WindowScan.Fence(marker: .backtick, length: 3)
        #expect(MarkerWithholding.withholdingPartialClosingFence(fence, in: input) == expected)
    }
}
