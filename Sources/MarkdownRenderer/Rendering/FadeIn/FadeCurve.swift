import Foundation

/// The fade-in as plain arithmetic, with no views involved, so every rule of
/// it can be tested directly.
///
/// Each glyph ramps from transparent to opaque over `duration`, eased out.
/// Inside one stretch of text the glyphs start `stagger` apart, left to
/// right, so a batch of text reads as typed rather than appearing as a slab.
struct FadeCurve: Equatable, Sendable {

    var duration: TimeInterval
    var stagger: TimeInterval

    /// A run of characters that arrived together.
    struct Stretch: Equatable {
        var range: Range<Int>
        /// `nil` for text that is drawn fully visible: text covered by a
        /// ``TextArrival/visible(upTo:)`` marker, or past the last arrival.
        var arrivalTime: TimeInterval?
    }

    /// Splits a text of `characterCount` characters at its arrivals.
    static func stretches(of arrivals: [TextArrival], characterCount: Int) -> [Stretch] {
        var stretches: [Stretch] = []
        var start = 0
        for arrival in arrivals {
            let end = min(arrival.characterCount, characterCount)
            guard end > start else { continue }
            stretches.append(Stretch(range: start..<end, arrivalTime: arrival.isVisible ? nil : arrival.time))
            start = end
        }
        if start < characterCount {
            stretches.append(Stretch(range: start..<characterCount, arrivalTime: nil))
        }
        return stretches
    }

    /// Whether any of the text still has a fade to draw, as opposed to being
    /// marked fully visible.
    static func hasFadingText(_ arrivals: [TextArrival]) -> Bool {
        arrivals.contains { !$0.isVisible }
    }

    /// When the last glyph is opaque. A stretch's last glyph starts
    /// `stagger × length` after its first, so this is an upper bound: the
    /// renderer restarts the stagger on every line. Never earlier than the
    /// reference date, so it always makes a valid `Date`.
    func endTime(of arrivals: [TextArrival]) -> TimeInterval {
        var start = 0
        var end: TimeInterval = 0
        for arrival in arrivals where arrival.characterCount > start {
            if !arrival.isVisible {
                let length = arrival.characterCount - start
                end = max(end, arrival.time + duration + stagger * Double(length))
            }
            start = arrival.characterCount
        }
        return end
    }

    /// Opacity of the glyph at `index` within a stretch that arrived `age`
    /// seconds ago: 0 before its turn, easing out to 1 over `duration`.
    func opacity(age: TimeInterval, glyphIndex index: Int) -> Double {
        guard duration > 0 else { return 1 }
        let progress = min(1, max(0, (age - stagger * Double(index)) / duration))
        return 1 - (1 - progress) * (1 - progress)
    }

    /// Whether every glyph of a stretch of `length` is already opaque.
    func isComplete(age: TimeInterval, length: Int) -> Bool {
        age >= duration + stagger * Double(length)
    }
}

extension FadeCurve {
    init(_ theme: MarkdownTheme) {
        self.init(duration: theme.fadeInDuration, stagger: theme.fadeInStagger)
    }
}
