import SwiftUI

/// Frames from now until `end`, then none: the `TimelineView` keeps its last
/// frame, which is drawn at `end` with every glyph opaque. An `end` in the
/// past yields a single frame.
///
/// The end comes from the arrivals rather than from view state, so a stream
/// that flushes several times per display frame simply hands the timeline a
/// later end instead of triggering a state change per flush.
struct FadeSchedule: TimelineSchedule {

    let end: Date

    /// Frame interval while the timeline runs. The display caps the rate.
    static let frameInterval: TimeInterval = 1.0 / 120

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> UnfoldFirstSequence<Date> {
        let interval = mode == .lowFrequency ? end.timeIntervalSince(startDate) : Self.frameInterval
        return sequence(first: startDate) { date in
            guard date < end else { return nil }
            return min(date.addingTimeInterval(max(interval, Self.frameInterval)), end)
        }
    }
}
