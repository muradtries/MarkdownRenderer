import Foundation

/// Stamps ``TextArrival``s onto the blocks of the window, for the fade-in.
///
/// The last block is the *animated* one: every flush that grows its text adds
/// an arrival for the new characters. When another block takes over as the
/// last one, the previous block keeps the arrivals it had, frozen, so text
/// that was still fading finishes its fade instead of snapping to full
/// opacity. Frozen arrivals never change again, so a settled block stays
/// equal to itself and SwiftUI never redraws it.
///
/// Blocks that arrive together in one flush, ahead of the last one, fade in
/// together from that flush.
///
/// Arrivals older than `retention` have finished fading. They collapse into
/// a single ``TextArrival/visible(upTo:)`` marker, which keeps the list short
/// however long the block grows.
struct ArrivalTracker: Sendable {

    let retention: TimeInterval

    private var animatedBlockID: Int?
    private var animated: [TextArrival] = []
    private var frozen: [Int: [TextArrival]] = [:]
    private var lastSeenID = -1

    init(retention: TimeInterval) {
        self.retention = retention
    }

    /// Stamps arrivals onto `blocks[window]`, the blocks just parsed from the
    /// window. The last of them is the animated block.
    mutating func stamp(_ blocks: inout [MarkdownBlock], window: Range<Int>, now: TimeInterval) {
        guard let last = window.last else { return }
        let lastID = blocks[last].id

        animate(blockID: lastID, now: now)
        for index in window.dropLast() {
            blocks[index].arrivals = arrivalsOfEarlierBlock(blocks[index], now: now)
        }
        blocks[last].arrivals = arrivalsOfAnimatedBlock(blocks[last].kind, now: now)

        frozen = frozen.filter { $0.key <= lastID }
        lastSeenID = lastID
    }

    /// Drops what is kept for blocks that have settled: their arrivals now
    /// live on the blocks themselves.
    mutating func forgetBlocks(before id: Int) {
        frozen = frozen.filter { $0.key >= id }
    }

    // MARK: - Steps

    /// Makes `blockID` the animated block, freezing the one before it.
    private mutating func animate(blockID: Int, now: TimeInterval) {
        guard animatedBlockID != blockID else { return }
        if let previous = animatedBlockID {
            frozen[previous] = frozenArrivals(animated, now: now)
        }
        animated = frozen.removeValue(forKey: blockID) ?? []
        animatedBlockID = blockID
    }

    /// A block before the last one keeps its frozen arrivals, or, when it
    /// appeared in this very flush, fades in as one stretch.
    private mutating func arrivalsOfEarlierBlock(_ block: MarkdownBlock, now: TimeInterval) -> [TextArrival] {
        guard let length = block.kind.fadeableLength else { return [] }
        if block.id > lastSeenID, length > 0 {
            frozen[block.id] = [TextArrival(characterCount: length, time: now)]
        } else if let arrivals = frozen[block.id] {
            frozen[block.id] = clamping(arrivals, to: length)
        }
        return frozen[block.id] ?? []
    }

    /// The animated block gains an arrival whenever its text grows.
    private mutating func arrivalsOfAnimatedBlock(_ kind: MarkdownBlock.Kind, now: TimeInterval) -> [TextArrival] {
        guard let length = kind.fadeableLength else {
            animated = []
            return []
        }
        animated = collapsingExpired(clamping(animated, to: length), now: now)
        if length > (animated.last?.characterCount ?? 0) {
            animated.append(TextArrival(characterCount: length, time: now))
        }
        return animated
    }

    // MARK: - Expiry

    /// Text can shrink between flushes, when a repair stops applying. The
    /// arrival that covered the cut keeps its time, so the characters before
    /// the cut do not fade in a second time.
    private func clamping(_ arrivals: [TextArrival], to length: Int) -> [TextArrival] {
        guard let cut = arrivals.firstIndex(where: { $0.characterCount > length }) else { return arrivals }
        var clamped = Array(arrivals[..<cut])
        if length > (clamped.last?.characterCount ?? 0) {
            clamped.append(TextArrival(characterCount: length, time: arrivals[cut].time))
        }
        return clamped
    }

    /// Arrivals are in time order, so the expired ones are a prefix. They
    /// become one marker at the furthest point they reached.
    private func collapsingExpired(_ arrivals: [TextArrival], now: TimeInterval) -> [TextArrival] {
        let expired = arrivals.prefix { now - $0.time > retention }
        guard let furthest = expired.last, !(expired.count == 1 && furthest.isVisible) else { return arrivals }
        return [.visible(upTo: furthest.characterCount)] + arrivals.dropFirst(expired.count)
    }

    /// A block that stops being animated gets no more arrivals. If none of
    /// its text is still fading it needs none at all, and draws as plain text.
    private func frozenArrivals(_ arrivals: [TextArrival], now: TimeInterval) -> [TextArrival] {
        let collapsed = collapsingExpired(arrivals, now: now)
        return collapsed.allSatisfy(\.isVisible) ? [] : collapsed
    }
}

extension MarkdownBlock.Kind {

    /// The number of characters the fade-in counts over: the block's text,
    /// or all of a list's item texts one after another. `nil` for kinds that
    /// are not animated.
    var fadeableLength: Int? {
        switch self {
        case .heading(_, let text), .paragraph(let text), .quote(let text):
            text.characters.count
        case .list(let items):
            items.reduce(0) { $0 + $1.text.characters.count }
        case .table, .divider:
            nil
        }
    }
}
