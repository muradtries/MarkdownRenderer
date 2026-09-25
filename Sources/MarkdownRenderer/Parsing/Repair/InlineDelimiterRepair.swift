import Foundation

/// Closes emphasis, strong, strikethrough and code-span delimiters that are
/// still open at the end of the text, so words arrive already styled:
///
///     "the **import"   →  "the **import**"
///     "use `max_to"    →  "use `max_to`"
///
/// This is not CommonMark's full delimiter-run algorithm; it only needs the
/// nesting right so that nothing dangles. The rules it does follow:
///
/// - code spans are literal, so delimiters inside them are ignored;
/// - a backslash escapes the next character;
/// - a run followed by whitespace cannot open, so a `* ` bullet or `2 * 3`
///   opens nothing, and a run preceded by whitespace cannot close;
/// - an `_` run only counts next to whitespace or punctuation, so
///   `snake_case_names` are left alone;
/// - closers go before trailing whitespace: `"**bold "` becomes
///   `"**bold** "`, because a closer after a space would not close.
enum InlineDelimiterRepair {

    static func apply(to text: String) -> String {
        let utf8 = UTF8Text(text)
        var open: [String] = []
        var offset = 0

        while offset < utf8.count {
            switch utf8[offset] {
            case .backslash:
                offset += 2

            case .backtick:
                let length = utf8.runLength(at: offset)
                guard let closing = backtickRun(ofLength: length, in: utf8, from: offset + length) else {
                    let codeCloser = String(repeating: "`", count: length)
                    return insertingClosers(codeCloser + open.reversed().joined(), into: utf8)
                }
                offset = closing + length

            case .asterisk, .underscore, .tilde:
                let length = utf8.runLength(at: offset)
                if let delimiter = delimiter(for: utf8[offset], length: length),
                   utf8[offset] != .underscore || isFlanking(utf8, offset: offset, length: length) {
                    if open.last == delimiter, !utf8.isWhitespace(before: offset) {
                        open.removeLast()
                    } else if !utf8.isWhitespace(at: offset + length) {
                        open.append(delimiter)
                    }
                }
                offset += length

            default:
                offset += 1
            }
        }

        return insertingClosers(open.reversed().joined(), into: utf8)
    }

    /// The delimiter a run stands for: `*`, `**` or `***` (and the `_`
    /// equivalents), or `~~`. A single `~` is not strikethrough.
    private static func delimiter(for byte: UInt8, length: Int) -> String? {
        if byte == .tilde {
            return length >= 2 ? "~~" : nil
        }
        return String(repeating: Character(Unicode.Scalar(byte)), count: min(length, 3))
    }

    private static func isFlanking(_ utf8: UTF8Text, offset: Int, length: Int) -> Bool {
        utf8.isBoundary(before: offset) || utf8.isBoundary(at: offset + length)
    }

    private static func backtickRun(ofLength length: Int, in utf8: UTF8Text, from start: Int) -> Int? {
        var offset = start
        while offset < utf8.count {
            guard utf8[offset] == .backtick else {
                offset += 1
                continue
            }
            let run = utf8.runLength(at: offset)
            if run == length { return offset }
            offset += run
        }
        return nil
    }

    private static func insertingClosers(_ closers: String, into utf8: UTF8Text) -> String {
        guard !closers.isEmpty else { return utf8.string }
        let end = utf8.endOfContent
        return utf8.substring(0..<end) + closers + utf8.substring(end..<utf8.count)
    }
}
