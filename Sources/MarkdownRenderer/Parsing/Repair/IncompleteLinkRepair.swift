import Foundation

/// Shows a half-arrived link as its label, so a partial URL is never drawn.
///
///     "see [the docs](https://ap"   →  "see the docs"
///     "see [the do"                 →  "see the do"
///     "![alt](htt"                  →  "alt"
///
/// The label turns back into a real link the moment the closing `)` arrives.
enum IncompleteLinkRepair {

    static func apply(to text: String) -> String {
        let utf8 = UTF8Text(text)

        if let separator = lastLabelDestinationSeparator(in: utf8),
           !utf8.bytes[(separator + 2)...].contains(.rightParenthesis),
           let bracket = utf8.bytes[..<separator].lastIndex(of: .leftBracket) {
            return replacingLink(in: utf8, openingBracket: bracket, labelEnd: separator)
        }

        if let bracket = utf8.bytes.lastIndex(of: .leftBracket),
           !utf8.bytes[bracket...].contains(.rightBracket) {
            return replacingLink(in: utf8, openingBracket: bracket, labelEnd: utf8.count)
        }

        return text
    }

    /// Offset of the `]` in the last `](`.
    private static func lastLabelDestinationSeparator(in utf8: UTF8Text) -> Int? {
        guard utf8.count >= 2 else { return nil }
        return stride(from: utf8.count - 2, through: 0, by: -1).first { offset in
            utf8[offset] == .rightBracket && utf8[offset + 1] == .leftParenthesis
        }
    }

    /// Everything before the link, then its label. An image's `!` goes too,
    /// so `![alt](u` does not leave a stray bang.
    private static func replacingLink(in utf8: UTF8Text, openingBracket bracket: Int, labelEnd: Int) -> String {
        let linkStart = bracket > 0 && utf8[bracket - 1] == .exclamationMark ? bracket - 1 : bracket
        return String(utf8.substring(0..<linkStart) + utf8.substring((bracket + 1)..<labelEnd))
    }
}
