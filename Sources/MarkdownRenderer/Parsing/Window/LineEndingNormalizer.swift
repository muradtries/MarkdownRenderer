import Foundation

/// Turns `\r\n` and lone `\r` into `\n`, one chunk at a time.
///
/// Swift treats `\r\n` as a single `Character`, so a line scan looking for
/// `"\n"` would never find a Windows line ending. A chunk can also end between
/// the `\r` and its `\n`. Converting that trailing `\r` right away would turn
/// the pair into two line breaks, and a blank line inside a code fence that was
/// never in the source. So a trailing `\r` is held back until the next chunk
/// shows whether a `\n` follows it.
struct LineEndingNormalizer: Sendable {

    private var heldCarriageReturn = false

    /// Normalizes one chunk. A `\r` at its end is held back and released by
    /// the next call, or by ``flush()``.
    mutating func normalize(_ chunk: String) -> String {
        var text = heldCarriageReturn ? "\r" + chunk : chunk
        heldCarriageReturn = false
        guard text.utf8.contains(.carriageReturn) else { return text }

        if text.utf8.last == .carriageReturn {
            heldCarriageReturn = true
            text.removeLast()
        }
        return Self.normalizeAll(text)
    }

    /// Releases a held `\r` as a line break, once the stream has ended.
    mutating func flush() -> String {
        defer { heldCarriageReturn = false }
        return heldCarriageReturn ? "\n" : ""
    }

    /// Normalizes a complete text in one pass over its bytes: every `\r`
    /// becomes `\n`, and a `\n` right after a `\r` is dropped.
    static func normalizeAll(_ text: String) -> String {
        guard text.utf8.contains(.carriageReturn) else { return text }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count)
        var followsCarriageReturn = false
        for byte in text.utf8 {
            if byte == .newline, followsCarriageReturn {
                followsCarriageReturn = false
                continue
            }
            followsCarriageReturn = byte == .carriageReturn
            bytes.append(followsCarriageReturn ? .newline : byte)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
