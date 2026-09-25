import Foundation

/// When a stretch of a block's text arrived, for the fade-in.
///
/// A block's arrivals are sorted by `characterCount`. Each one covers the
/// characters from the previous arrival's count up to its own, and says when
/// they arrived; the first one starts at character 0:
///
///     [visible(upTo: 40), (52, t₁), (60, t₂)]
///     characters 0..<40   already fully visible
///     characters 40..<52  arrived at t₁
///     characters 52..<60  arrived at t₂
///
/// Times are `Date.timeIntervalSinceReferenceDate`, so a `TimelineView` can
/// compare them with its own dates directly. Text past the last arrival is
/// drawn fully visible.
public struct TextArrival: Equatable, Sendable {

    /// The block's text length, in `Character`s, once this stretch arrived.
    public var characterCount: Int

    /// When this stretch arrived, or `-infinity` for text that is already
    /// fully visible.
    public var time: TimeInterval

    public init(characterCount: Int, time: TimeInterval) {
        self.characterCount = characterCount
        self.time = time
    }

    /// Marks everything up to `characterCount` as already fully visible, so it
    /// is drawn without fading. The parser collapses arrivals that have
    /// finished fading into one of these.
    public static func visible(upTo characterCount: Int) -> TextArrival {
        TextArrival(characterCount: characterCount, time: -.infinity)
    }

    /// Whether this arrival is a ``visible(upTo:)`` marker.
    public var isVisible: Bool {
        time == -.infinity
    }
}

extension TextArrival {

    /// The part of `arrivals` that covers `range`, re-counted from the start
    /// of that range.
    ///
    /// A list's arrivals count over all of its items' texts; this hands each
    /// item the stretches that fall inside its own text.
    static func slice(_ arrivals: [TextArrival], to range: Range<Int>) -> [TextArrival] {
        var result: [TextArrival] = []
        var stretchStart = 0
        for arrival in arrivals {
            let stretch = stretchStart..<max(stretchStart, arrival.characterCount)
            stretchStart = stretch.upperBound
            guard stretch.overlaps(range) else { continue }
            let end = min(stretch.upperBound, range.upperBound) - range.lowerBound
            result.append(TextArrival(characterCount: end, time: arrival.time))
        }
        return result
    }
}
