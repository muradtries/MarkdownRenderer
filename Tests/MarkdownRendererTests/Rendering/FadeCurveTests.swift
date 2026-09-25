import SwiftUI
import Testing
@testable import MarkdownRenderer

@Suite("FadeCurve")
struct FadeCurveTests {

    private let curve = FadeCurve(duration: 0.5, stagger: 0.01)

    @Test("Stretches cut the text at its arrivals; visible and trailing text is untagged")
    func stretches() {
        let arrivals = [TextArrival.visible(upTo: 4), TextArrival(characterCount: 7, time: 10), TextArrival(characterCount: 9, time: 11)]
        #expect(FadeCurve.stretches(of: arrivals, characterCount: 12) == [
            .init(range: 0..<4, arrivalTime: nil),
            .init(range: 4..<7, arrivalTime: 10),
            .init(range: 7..<9, arrivalTime: 11),
            .init(range: 9..<12, arrivalTime: nil),
        ])
    }

    @Test("Stretches clamp arrivals that point past the text and skip empty ones")
    func stretchesClamp() {
        let arrivals = [TextArrival(characterCount: 3, time: 1), TextArrival(characterCount: 3, time: 2), TextArrival(characterCount: 50, time: 3)]
        #expect(FadeCurve.stretches(of: arrivals, characterCount: 5) == [
            .init(range: 0..<3, arrivalTime: 1),
            .init(range: 3..<5, arrivalTime: 3),
        ])
        #expect(FadeCurve.stretches(of: [], characterCount: 0) == [])
    }

    @Test("Only a non-visible arrival makes text fade")
    func hasFadingText() {
        #expect(!FadeCurve.hasFadingText([]))
        #expect(!FadeCurve.hasFadingText([.visible(upTo: 10)]))
        #expect(FadeCurve.hasFadingText([.visible(upTo: 10), TextArrival(characterCount: 12, time: 1)]))
    }

    @Test("The fade ends when the slowest stretch's last glyph is opaque")
    func endTime() {
        let arrivals = [TextArrival(characterCount: 10, time: 100), TextArrival(characterCount: 12, time: 100.2)]
        #expect(abs(curve.endTime(of: arrivals) - 100.72) < 1e-9)
        #expect(curve.endTime(of: [.visible(upTo: 10)]) == 0)
        #expect(curve.endTime(of: []) == 0)
    }

    @Test("Opacity eases from 0 to 1, each glyph starting one stagger later")
    func opacity() {
        #expect(curve.opacity(age: 0, glyphIndex: 0) == 0)
        #expect(curve.opacity(age: 0.25, glyphIndex: 0) == 0.75)
        #expect(curve.opacity(age: 0.5, glyphIndex: 0) == 1)
        #expect(curve.opacity(age: 0.5, glyphIndex: 50) == 0)
        #expect(curve.opacity(age: -1, glyphIndex: 0) == 0)
        #expect(curve.opacity(age: .infinity, glyphIndex: 0) == 1)
        #expect(FadeCurve(duration: 0, stagger: 0).opacity(age: 0, glyphIndex: 0) == 1)
    }

    @Test("A stretch is complete once its last glyph has had the full duration")
    func isComplete() {
        #expect(!curve.isComplete(age: 0.5, length: 10))
        #expect(curve.isComplete(age: 0.61, length: 10))
        #expect(curve.isComplete(age: .infinity, length: 1000))
    }

    @Test("The curve comes from the theme")
    func fromTheme() {
        var theme = MarkdownTheme()
        theme.fadeInDuration = 0.3
        theme.fadeInStagger = 0.002
        #expect(FadeCurve(theme) == FadeCurve(duration: 0.3, stagger: 0.002))
    }
}

@Suite("FadeSchedule")
struct FadeScheduleTests {

    private let start = Date(timeIntervalSinceReferenceDate: 100)

    @Test("Frames run from the start to the end, and stop there")
    func runsUntilEnd() {
        let schedule = FadeSchedule(end: start.addingTimeInterval(0.105))
        let dates = Array(schedule.entries(from: start, mode: .normal))
        #expect(dates.first == start)
        #expect(dates.last == start.addingTimeInterval(0.105))
        #expect(dates.count == 14)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("An end in the past yields a single frame")
    func pastEnd() {
        let schedule = FadeSchedule(end: start.addingTimeInterval(-5))
        #expect(Array(schedule.entries(from: start, mode: .normal)) == [start])
    }

    @Test("Low-frequency mode jumps straight to the end")
    func lowFrequency() {
        let schedule = FadeSchedule(end: start.addingTimeInterval(1))
        #expect(Array(schedule.entries(from: start, mode: .lowFrequency)) == [start, start.addingTimeInterval(1)])
    }
}

@Suite("InlineStyling")
struct InlineStylingTests {

    @Test("Code gets the theme's background and links an underline; nothing else changes")
    func styling() {
        var code = AttributedString("code")
        code.inlinePresentationIntent = .code
        var link = AttributedString("link")
        link.link = URL(string: "https://example.com")
        var strong = AttributedString("strong")
        strong.inlinePresentationIntent = .stronglyEmphasized
        let text = AttributedString("plain ") + code + AttributedString(" ") + link + AttributedString(" ") + strong

        var theme = MarkdownTheme()
        theme.inlineCodeBackground = .orange
        let styled = InlineStyling.styled(text, theme: theme)

        #expect(String(styled.characters) == String(text.characters))
        for run in styled.runs {
            let fragment = String(styled[run.range].characters)
            #expect((run.backgroundColor == .orange) == (fragment == "code"), "\(fragment)")
            #expect((run.underlineStyle == .single) == (fragment == "link"), "\(fragment)")
            #expect(run.font == nil, "\(fragment) keeps the surrounding font")
        }
    }
}
