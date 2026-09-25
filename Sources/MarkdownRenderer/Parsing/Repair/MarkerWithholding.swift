import Foundation

/// Holds back a last line that is only the start of a block, until its
/// content arrives.
///
/// Without this, `-` streams in and cmark reports a paragraph containing
/// `-`, which becomes an empty bullet a moment later; `1` shows as a number
/// and then vanishes when the `.` turns it into a list marker. Withholding
/// the line for one chunk means the block appears as itself, once.
///
/// Only the last line is ever withheld, and only while it has no line break
/// after it, so the cost is at most one chunk of delay.
enum MarkerWithholding {

    static func apply(to text: String) -> String {
        guard let lineStart = partialLastLineStart(of: text),
              isMarkerOnly(text.utf8[lineStart...])
        else { return text }
        return String(text[..<lineStart])
    }

    /// Inside an open fence the only thing that can flash is the closing
    /// fence itself: `` `` `` renders as code, then disappears when the
    /// third backtick closes the fence.
    static func withholdingPartialClosingFence(_ fence: WindowScan.Fence, in text: String) -> String {
        guard let lineStart = partialLastLineStart(of: text) else { return text }
        let body = text.utf8[lineStart...].drop(while: \.isSpaceOrTab)
        guard !body.isEmpty, body.allSatisfy({ $0 == fence.marker }) else { return text }
        return String(text[..<lineStart])
    }

    /// Whether a line is nothing but block markers so far.
    ///
    /// Container markers (`>`, `-`, `1.` followed by a space) are peeled off
    /// first; what remains must be empty, the start of another marker
    /// (`#`, `|`, `` ` ``, a number), or a task box that has not closed yet
    /// (`[`, `[x`, `[ ]`). A thematic break (`---`, `* * *`) is complete
    /// content and is never withheld.
    static func isMarkerOnly(_ line: Substring.UTF8View) -> Bool {
        let body = line.trimmingSpacesAndTabs()
        guard !body.isEmpty, !isThematicBreak(body) else { return false }

        var rest = body
        var followsListMarker = false
        while true {
            if rest.first == .greaterThan {
                rest = rest.dropFirst().drop(while: \.isSpaceOrTab)
                followsListMarker = false
            } else if let length = listMarkerLength(of: rest), rest.dropFirst(length).first?.isSpaceOrTab == true {
                rest = rest.dropFirst(length).drop(while: \.isSpaceOrTab)
                followsListMarker = true
            } else {
                break
            }
        }

        if rest.isEmpty { return true }
        if followsListMarker, isUnfinishedTaskBox(rest) { return true }
        return !isThematicBreak(rest) && isUnfinishedMarker(rest)
    }

    // MARK: - Pieces

    /// Start of the last line, or `nil` when the text ends with a line break
    /// and so has no unfinished line.
    private static func partialLastLineStart(of text: String) -> String.Index? {
        let utf8 = text.utf8
        guard let last = utf8.last, last != .newline else { return nil }
        return utf8.lastIndex(of: .newline).map(utf8.index(after:)) ?? utf8.startIndex
    }

    /// `#`, `##`, `|`, `` ``` ``, `~`, `-`: only marker characters so far.
    /// Or up to nine digits, optionally followed by the `.` or `)` of an
    /// ordered list marker.
    private static func isUnfinishedMarker(_ text: Substring.UTF8View) -> Bool {
        if text.allSatisfy(isMarkerCharacter) { return true }
        let digits = text.prefix(while: \.isASCIIDigit).count
        guard (1...9).contains(digits) else { return false }
        let suffix = text.dropFirst(digits)
        return suffix.isEmpty || (suffix.count == 1 && (suffix.first == .period || suffix.first == .rightParenthesis))
    }

    private static func isMarkerCharacter(_ byte: UInt8) -> Bool {
        switch byte {
        case .hash, .hyphen, .asterisk, .plus, .greaterThan, .pipe, .backtick, .tilde: true
        default: false
        }
    }

    /// `[`, `[ `, `[x`, `[X`, `[ ]`, `[x]` — a task box still being typed.
    private static func isUnfinishedTaskBox(_ text: Substring.UTF8View) -> Bool {
        let bytes = Array(text)
        guard bytes.first == .leftBracket, bytes.count <= 3 else { return false }
        if bytes.count >= 2, ![UInt8.space, UInt8(ascii: "x"), UInt8(ascii: "X")].contains(bytes[1]) { return false }
        if bytes.count == 3, bytes[2] != .rightBracket { return false }
        return true
    }

    /// `-`, `*` or `+`, or one to nine digits and `.` or `)`.
    private static func listMarkerLength(of text: Substring.UTF8View) -> Int? {
        guard let first = text.first else { return nil }
        if first == .hyphen || first == .asterisk || first == .plus { return 1 }
        let digits = text.prefix(while: \.isASCIIDigit).count
        guard (1...9).contains(digits) else { return nil }
        let delimiter = text.dropFirst(digits).first
        return delimiter == .period || delimiter == .rightParenthesis ? digits + 1 : nil
    }

    /// Three or more of the same `-`, `*` or `_`, optionally spaced.
    private static func isThematicBreak(_ text: Substring.UTF8View) -> Bool {
        guard let marker = text.first, marker == .hyphen || marker == .asterisk || marker == .underscore else { return false }
        var count = 0
        for byte in text {
            if byte == marker {
                count += 1
            } else if !byte.isSpaceOrTab {
                return false
            }
        }
        return count >= 3
    }
}

extension Substring.UTF8View {
    func trimmingSpacesAndTabs() -> Substring.UTF8View {
        var result = drop(while: \.isSpaceOrTab)
        while let last = result.last, last.isSpaceOrTab {
            result = result.dropLast()
        }
        return result
    }
}
