import Testing
@testable import MarkdownRenderer

@Suite("TableCompletion")
struct TableCompletionTests {

    @Test("Synthesises or completes the delimiter row", arguments: [
        ("| a", "| a\n| --- |"),
        ("| a | b |", "| a | b |\n| --- | --- |"),
        ("| a | b |\n", "| a | b |\n| --- | --- |\n"),
        ("| a | b |\n|", "| a | b |\n| --- | --- |"),
        ("| a | b |\n| ", "| a | b |\n| --- | --- |"),
        ("| a | b |\n| --- | :-", "| a | b |\n| --- | --- |"),
        ("| a | b |\n| --- | :-:", "| a | b |\n| --- | :-: |"),
        ("| a | b |\n| :-- | :", "| a | b |\n| --- | --- |"),
        ("| a | b |\n| :-- | --:", "| a | b |\n| --- | --: |"),
        ("| a | b |\n| --- | --: |\n| 1", "| a | b |\n| --- | --: |\n| 1"),
        ("| a | b |\n| --- |\n", "| a | b |\n| --- |\n"),
        ("| a | b |\n| --- |\n| 1", "| a | b |\n| --- |\n| 1"),
        ("| a | b |\n|--|--|\n| 1 | 2", "| a | b |\n|--|--|\n| 1 | 2"),
        ("| a \\| b |", "| a \\| b |\n| --- |"),
        ("| a | b \\|", "| a | b \\|\n| --- | --- |"),
        (" | a | b |", " | a | b |\n| --- | --- |"),
        ("   | a |", "   | a |\n| --- |"),
        ("    | not a row |", "    | not a row |"),
        ("| |", "| |"),
        ("|", "|"),
        ("plain text", "plain text"),
        ("| a |\n| x |", "| a |\n| x |"),
        ("| a |\n| b |\n| -", "| a |\n| b |\n| -"),
        ("prose\n| a | b", "prose\n| a | b\n| --- | --- |"),
        ("| a |\n| --- |\n| 1 |\n\ntext\n| c | d", "| a |\n| --- |\n| 1 |\n\ntext\n| c | d\n| --- | --- |"),
        ("", ""),
        ("\n", "\n"),
        ("| 名前 | 値", "| 名前 | 値\n| --- | --- |"),
    ])
    func completesDelimiterRow(input: String, expected: String) {
        #expect(TableCompletion.apply(to: input) == expected)
    }

    @Test("Counts cells the way GFM does", arguments: [
        ("| a | b |", 2),
        ("| a | b", 2),
        ("a | b", 2),
        ("| a |", 1),
        ("| a", 1),
        ("| a \\| b |", 1),
        ("| a | b \\|", 2),
        ("|", 0),
        ("| |", 0),
        ("||", 0),
        ("| | |", 2),
        ("  | a | b |  ", 2),
    ])
    func countsCells(line: String, expected: Int) {
        #expect(TableCompletion.cellCount(of: Substring(line)) == expected)
    }

    @Test("A long table is completed by looking only at its last lines")
    func longTable() {
        let rows = String(repeating: "| x | y |\n", count: 500)
        let table = "| a | b |\n| --- | --- |\n" + rows + "| partial"
        #expect(TableCompletion.apply(to: table) == table)
    }
}
