import Foundation

/// What a stream has cost so far, so an app can measure instead of guess.
/// Read it from ``IncrementalMarkdownParser/Snapshot/metrics``.
public struct ParseMetrics: Equatable, Sendable {

    /// Parses so far: one per append that changed the window, plus one for
    /// `finish()`.
    public var parseCount = 0

    /// Characters handed to cmark, summed over every parse. With windowing
    /// this grows linearly with the response; re-parsing the whole response on
    /// every chunk would make it grow quadratically.
    public var charactersScanned = 0

    /// Time spent re-parsing the window: scan, streaming repairs, cmark and
    /// conversion to blocks.
    public var parseDuration: Duration = .zero

    /// Blocks in the document so far.
    public var blockCount = 0

    public init() {}

    public var averageParseMilliseconds: Double {
        guard parseCount > 0 else { return 0 }
        return parseDuration.seconds * 1000 / Double(parseCount)
    }

    mutating func record(parse duration: Duration, characters: Int) {
        parseCount += 1
        charactersScanned += characters
        parseDuration += duration
    }
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
