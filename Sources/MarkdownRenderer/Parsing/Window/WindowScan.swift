import Foundation

/// One pass over the window's lines that answers the three questions the
/// parser has before each parse:
///
/// - Where may streaming repairs start? After the last blank line or closing
///   fence: inline syntax never spans either, so text before that point is
///   complete as far as repairs are concerned.
/// - Where can blocks settle? Only at a line that follows a blank line.
/// - Does the window end inside a code fence? Then its contents are literal,
///   and nothing in them may be repaired or treated as a block boundary.
///
/// Fences are followed with CommonMark's rules: a closing fence uses the same
/// character, is at least as long as the opening one and carries no info
/// string. Indentation is not limited to three spaces, because a fence nested
/// in a list item is indented further, and that is far more common in model
/// output than a four-space indented code block.
struct WindowScan: Equatable {

    struct Fence: Equatable {
        /// `` ` `` or `~`.
        var marker: UInt8
        var length: Int
    }

    /// Start of the text streaming repairs may touch.
    var repairStart: String.Index

    /// 1-based numbers of the lines that have content and directly follow a
    /// blank line outside a fence. A block starting on one of these lines
    /// cannot merge with anything before it.
    var linesAfterBlankLine: Set<Int>

    /// The fence the window ends inside, if any.
    var openFence: Fence?

    init(_ source: String) {
        let utf8 = source.utf8
        repairStart = utf8.startIndex
        linesAfterBlankLine = []
        openFence = nil

        var lineStart = utf8.startIndex
        var lineNumber = 1
        var previousLineWasBlank = false

        while lineStart < utf8.endIndex {
            let newline = utf8[lineStart...].firstIndex(of: .newline)
            let body = utf8[lineStart..<(newline ?? utf8.endIndex)].drop(while: \.isSpaceOrTab)
            let nextLineStart = newline.map(utf8.index(after:)) ?? utf8.endIndex

            if !body.isEmpty {
                if previousLineWasBlank { linesAfterBlankLine.insert(lineNumber) }
                previousLineWasBlank = false
            }

            if let fence = openFence {
                if fence.isClosed(by: body) {
                    openFence = nil
                    repairStart = nextLineStart
                }
            } else if let fence = Fence(opening: body) {
                openFence = fence
            } else if body.isEmpty, newline != nil {
                previousLineWasBlank = true
                repairStart = nextLineStart
            }

            lineStart = nextLineStart
            lineNumber += 1
        }
    }
}

extension WindowScan.Fence {

    /// The fence a line opens: three or more backticks or tildes. A backtick
    /// fence's info string may not contain a backtick, or the line is inline
    /// code instead.
    init?(opening body: Substring.UTF8View) {
        guard let marker = body.first, marker == .backtick || marker == .tilde else { return nil }
        let length = body.prefix { $0 == marker }.count
        guard length >= 3 else { return nil }
        if marker == .backtick, body.dropFirst(length).contains(.backtick) { return nil }
        self.init(marker: marker, length: length)
    }

    func isClosed(by body: Substring.UTF8View) -> Bool {
        let run = body.prefix { $0 == marker }.count
        return run >= length && body.dropFirst(run).allSatisfy(\.isSpaceOrTab)
    }
}
