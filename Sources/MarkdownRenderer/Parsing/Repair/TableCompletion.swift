import Foundation

/// Makes a half-arrived table parse as a table.
///
/// GFM only recognises a table once its delimiter row (`| --- | --- |`) is
/// complete, so while the header streams in, cmark reports a paragraph and
/// the reader watches `| Technique | Fixes |` sit on screen as literal pipes.
/// The header is signal enough: as soon as a line starts with `|` and has a
/// cell, this appends a delimiter row with one column per header cell, and
/// the text renders as a table from its first cell. A real delimiter row that
/// is still arriving is replaced by a complete one with whatever alignments
/// it has declared so far; once it ends with a line break it is left alone.
///
/// Only the last three lines are inspected, so a long table costs no more
/// than a short one.
enum TableCompletion {

    static func apply(to tail: String) -> String {
        let endsWithNewline = tail.utf8.last == .newline
        let body = endsWithNewline ? tail.dropLast() : tail[...]
        let lines = lastLines(of: body, count: 3)
        guard let last = lines.last else { return tail }
        let previous = lines.count >= 2 ? lines[lines.count - 2] : nil
        let beforePrevious = lines.count == 3 ? lines[0] : nil

        if isRow(last), !(previous.map(isRow) ?? false) {
            let columns = cellCount(of: last)
            guard columns > 0 else { return tail }
            let row = delimiterRow(columns: columns, alignments: [])
            return endsWithNewline ? tail + row + "\n" : tail + "\n" + row
        }

        if !endsWithNewline, let header = previous, isRow(header), !(beforePrevious.map(isRow) ?? false),
           isPendingDelimiterRow(last) {
            let columns = cellCount(of: header)
            guard columns > 0 else { return tail }
            return tail[..<last.startIndex] + delimiterRow(columns: columns, alignments: alignments(in: last))
        }

        return tail
    }

    // MARK: - Rows

    /// A line that begins a table row: `|` after at most three spaces.
    static func isRow(_ line: Substring) -> Bool {
        let indent = line.utf8.prefix { $0 == .space }.count
        return indent <= 3 && line.utf8.dropFirst(indent).first == .pipe
    }

    /// Cells in a row as GFM counts them: a leading and a trailing pipe are
    /// not cell boundaries, and `\|` is an escaped pipe inside a cell.
    static func cellCount(of line: Substring) -> Int {
        var body = line.utf8.trimmingSpacesAndTabs()
        if body.first == .pipe { body = body.dropFirst() }
        if body.last == .pipe, body.dropLast().last != .backslash { body = body.dropLast() }
        guard body.contains(where: { !$0.isSpaceOrTab }) else { return 0 }

        var count = 1
        var previous: UInt8?
        for byte in body {
            if byte == .pipe, previous != .backslash { count += 1 }
            previous = byte
        }
        return count
    }

    // MARK: - Delimiter row

    /// Nothing but the characters a delimiter row is made of. A row that is
    /// just `|` or `| ` counts too, so the table does not flicker back to a
    /// paragraph between the header and the first dash.
    private static func isPendingDelimiterRow(_ line: Substring) -> Bool {
        isRow(line) && line.utf8.allSatisfy { [.pipe, .hyphen, .colon, .space].contains($0) }
    }

    /// Alignments a partial delimiter row has declared, cell by cell.
    private static func alignments(in line: Substring) -> [MarkdownTable.Alignment] {
        var body = line.trimmingCharacters(in: .whitespaces)[...]
        if body.first == "|" { body = body.dropFirst() }
        return body.split(separator: "|", omittingEmptySubsequences: false).map { cell in
            let cell = cell.trimmingCharacters(in: .whitespaces)
            switch (cell.hasPrefix(":"), cell.hasSuffix(":") && cell.count > 1) {
            case (true, true): return .center
            case (false, true): return .trailing
            default: return .leading
            }
        }
    }

    private static func delimiterRow(columns: Int, alignments: [MarkdownTable.Alignment]) -> String {
        let cells = (0..<columns).map { column -> String in
            switch alignments.indices.contains(column) ? alignments[column] : .leading {
            case .leading: "---"
            case .center: ":-:"
            case .trailing: "--:"
            }
        }
        return "| " + cells.joined(separator: " | ") + " |"
    }

    // MARK: - Lines

    /// Up to `count` lines from the end of `text`, in reading order.
    private static func lastLines(of text: Substring, count: Int) -> [Substring] {
        var lines: [Substring] = []
        var end = text.endIndex
        while lines.count < count {
            let newline = text.utf8[..<end].lastIndex(of: .newline)
            let start = newline.map(text.utf8.index(after:)) ?? text.startIndex
            lines.insert(text[start..<end], at: 0)
            guard let newline else { break }
            end = newline
        }
        return lines
    }
}
