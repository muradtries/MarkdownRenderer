import Testing
@testable import MarkdownRenderer

@Suite("InlineDelimiterRepair")
struct InlineDelimiterRepairTests {

    @Test("Balances dangling delimiters", arguments: [
        ("plain", "plain"),
        ("", ""),
        ("**open", "**open**"),
        ("*a **b", "*a **b***"),
        ("***both", "***both***"),
        ("__strong", "__strong__"),
        ("_a *b", "_a *b*_"),
        ("**a*", "**a***"),
        ("~~gone", "~~gone~~"),
        ("~single", "~single"),
        ("~~a~~ b", "~~a~~ b"),
        ("`code", "`code`"),
        ("``double `tick", "``double `tick``"),
        ("**`x", "**`x`**"),
        ("`**` and **x", "`**` and **x**"),
        ("**done** and *more", "**done** and *more*"),
        ("**closed** text", "**closed** text"),
        ("snake_case_name", "snake_case_name"),
        ("max_tokens is _emph", "max_tokens is _emph_"),
        ("escaped \\* star", "escaped \\* star"),
        ("escaped \\** star", "escaped \\** star"),
        ("trailing backslash \\", "trailing backslash \\"),
        ("**", "**"),
        ("* item", "* item"),
        ("* one\n* two\n* three", "* one\n* two\n* three"),
        ("- a *b", "- a *b*"),
        ("2 * 3 = 6", "2 * 3 = 6"),
        ("a **b **c", "a **b **c****"),
        ("a **b** **c", "a **b** **c**"),
        ("**open ", "**open** "),
        ("*a b ", "*a b* "),
        ("**x\n", "**x**\n"),
        ("~~gone  ", "~~gone~~  "),
        ("`code ", "`code` "),
        ("**a *b ", "**a *b*** "),
        ("plain ", "plain "),
    ])
    func balancesDelimiters(input: String, expected: String) {
        #expect(InlineDelimiterRepair.apply(to: input) == expected)
    }

    @Test("Unicode neighbours are classified by their scalar", arguments: [
        ("**жирный", "**жирный**"),
        ("*наклон* и **жир", "*наклон* и **жир**"),
        ("日本語の_強調", "日本語の_強調"),
        ("「_quoted", "「_quoted_"),
        ("👍 **yes", "👍 **yes**"),
        ("**flag 🇺🇸", "**flag 🇺🇸**"),
        ("**e\u{301}", "**e\u{301}**"),
        ("**a\u{00A0}", "**a**\u{00A0}"),
        ("`コード", "`コード`"),
    ])
    func unicodeNeighbours(input: String, expected: String) {
        #expect(InlineDelimiterRepair.apply(to: input) == expected)
    }
}

@Suite("IncompleteLinkRepair")
struct IncompleteLinkRepairTests {

    @Test("Hides half-arrived links", arguments: [
        ("see [docs](http", "see docs"),
        ("see [docs](http://x.y/with space", "see docs"),
        ("see [docs", "see docs"),
        ("see [", "see "),
        ("![alt](htt", "alt"),
        ("![", ""),
        ("[a]", "[a]"),
        ("[a]()", "[a]()"),
        ("done [link](https://x.y) ok", "done [link](https://x.y) ok"),
        ("[a](b) [c", "[a](b) c"),
        ("[a](b) [c](d", "[a](b) c"),
        ("plain text", "plain text"),
        ("array[0] index", "array[0] index"),
        ("", ""),
        ("[ссылка](https://при", "ссылка"),
        ("see [🚀 launch](ht", "see 🚀 launch"),
    ])
    func truncatesIncompleteLinks(input: String, expected: String) {
        #expect(IncompleteLinkRepair.apply(to: input) == expected)
    }
}

@Suite("ProvisionalSource")
struct ProvisionalSourceTests {

    @Test("Link hiding runs before delimiter balancing", arguments: [
        ("[**bo](x", "**bo**"),
        ("see [*the docs*](https://ap", "see *the docs*"),
        ("**see [docs](ht", "**see docs**"),
    ])
    func repairsInOrder(input: String, expected: String) {
        #expect(provisional(input) == expected)
    }

    @Test("A closer lands in the table header, before the synthesised delimiter row")
    func closerBeforeDelimiterRow() {
        #expect(provisional("| **a") == "| **a**\n| --- |")
    }

    @Test("Only the text after the last blank line is repaired")
    func headIsUntouched() {
        #expect(provisional("**a\n\n**b") == "**a\n\n**b**")
    }

    @Test("Inside an open fence nothing is repaired, and only a partial closer is withheld")
    func fenceIsLiteral() {
        #expect(provisional("```\n**a [b](c") == "```\n**a [b](c")
        #expect(provisional("```\ncode\n``") == "```\ncode\n")
        #expect(provisional("~~~\ncode\n``") == "~~~\ncode\n``")
    }

    @Test("With no repairs the window is passed through untouched")
    func noRepairs() {
        let window = "intro\n\n**a [b](c\n-"
        #expect(ProvisionalSource.make(from: window, scan: WindowScan(window), repairs: []) == window)
    }

    private func provisional(_ window: String) -> String {
        ProvisionalSource.make(from: window, scan: WindowScan(window), repairs: .all)
    }
}
