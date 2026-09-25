import Foundation

/// A string's UTF-8 bytes, with just enough Unicode awareness to classify the
/// character on either side of a markdown delimiter.
///
/// Every piece of syntax the streaming repairs look for is ASCII, so they
/// scan bytes instead of `Character`s: no grapheme breaking, and an `Int`
/// index is a plain array offset. An ASCII byte never occurs inside a
/// multi-byte scalar, so cutting the string at one is always safe.
struct UTF8Text {

    let string: String
    let bytes: [UInt8]

    init(_ string: String) {
        self.string = string
        self.bytes = Array(string.utf8)
    }

    var count: Int { bytes.count }

    subscript(offset: Int) -> UInt8 { bytes[offset] }

    /// The string index at a byte offset. Only valid for offsets on a scalar
    /// boundary, which every ASCII byte is.
    func index(at offset: Int) -> String.Index {
        string.utf8.index(string.utf8.startIndex, offsetBy: offset)
    }

    /// The text between two byte offsets.
    func substring(_ range: Range<Int>) -> Substring {
        string[index(at: range.lowerBound)..<index(at: range.upperBound)]
    }

    /// The scalar starting at `offset`, or `nil` at the end.
    func scalar(at offset: Int) -> Unicode.Scalar? {
        guard offset < bytes.count else { return nil }
        if bytes[offset] < 0x80 { return Unicode.Scalar(bytes[offset]) }
        var iterator = bytes[offset...].makeIterator()
        var decoder = UTF8()
        guard case .scalarValue(let scalar) = decoder.decode(&iterator) else { return nil }
        return scalar
    }

    /// The scalar ending just before `offset`, or `nil` at the start.
    func scalar(before offset: Int) -> Unicode.Scalar? {
        guard offset > 0 else { return nil }
        var start = offset - 1
        while start > 0, bytes[start].isUTF8Continuation {
            start -= 1
        }
        return scalar(at: start)
    }

    /// Whitespace, or the edge of the text, which delimiter rules treat the
    /// same way.
    func isWhitespace(at offset: Int) -> Bool {
        scalar(at: offset)?.properties.isWhitespace ?? true
    }

    func isWhitespace(before offset: Int) -> Bool {
        scalar(before: offset)?.properties.isWhitespace ?? true
    }

    /// Whitespace, punctuation, a symbol, or the edge of the text: the
    /// characters that let an `_` run open or close emphasis.
    func isBoundary(at offset: Int) -> Bool {
        scalar(at: offset).map(\.isBoundary) ?? true
    }

    func isBoundary(before offset: Int) -> Bool {
        scalar(before: offset).map(\.isBoundary) ?? true
    }

    /// Byte offset just past the last character that is not whitespace.
    var endOfContent: Int {
        var end = bytes.count
        while let scalar = scalar(before: end), scalar.properties.isWhitespace {
            end -= scalar.utf8.count
        }
        return end
    }

    /// How many times the byte at `offset` repeats from there.
    func runLength(at offset: Int) -> Int {
        let byte = bytes[offset]
        var end = offset
        while end < bytes.count, bytes[end] == byte {
            end += 1
        }
        return end - offset
    }
}

private extension Unicode.Scalar {
    var isBoundary: Bool {
        if properties.isWhitespace { return true }
        switch properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation,
             .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            return true
        default:
            return false
        }
    }
}

extension UInt8 {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let backslash = UInt8(ascii: "\\")
    static let backtick = UInt8(ascii: "`")
    static let tilde = UInt8(ascii: "~")
    static let asterisk = UInt8(ascii: "*")
    static let underscore = UInt8(ascii: "_")
    static let plus = UInt8(ascii: "+")
    static let hyphen = UInt8(ascii: "-")
    static let hash = UInt8(ascii: "#")
    static let greaterThan = UInt8(ascii: ">")
    static let pipe = UInt8(ascii: "|")
    static let colon = UInt8(ascii: ":")
    static let period = UInt8(ascii: ".")
    static let exclamationMark = UInt8(ascii: "!")
    static let leftBracket = UInt8(ascii: "[")
    static let rightBracket = UInt8(ascii: "]")
    static let leftParenthesis = UInt8(ascii: "(")
    static let rightParenthesis = UInt8(ascii: ")")

    var isSpaceOrTab: Bool { self == .space || self == .tab }

    var isASCIIDigit: Bool { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self) }

    var isUTF8Continuation: Bool { self & 0b1100_0000 == 0b1000_0000 }
}
