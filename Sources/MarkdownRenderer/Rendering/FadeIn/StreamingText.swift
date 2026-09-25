import SwiftUI

/// Text whose recently arrived characters fade in.
///
/// On iOS 18 this uses a `TextRenderer`: each stretch of text is tagged with
/// the time it arrived, and the renderer draws every glyph with an opacity
/// derived from its age. SwiftUI lays the text out once per flush as usual;
/// the per-frame work is only the draw pass over one block, and it stops as
/// soon as the last glyph is opaque. Below iOS 18 there is no renderer API,
/// and re-laying-out text every frame to fake one is exactly the cost that
/// drops frames, so those versions draw static text.
struct StreamingText: View {

    /// Fully styled text.
    let text: AttributedString
    let arrivals: [TextArrival]
    let curve: FadeCurve

    var body: some View {
        if #available(iOS 18.0, *), FadeCurve.hasFadingText(arrivals) {
            FadingText(text: text, arrivals: arrivals, curve: curve)
        } else {
            Text(text)
        }
    }
}

@available(iOS 18.0, *)
private struct FadingText: View {

    let text: AttributedString
    let arrivals: [TextArrival]
    let curve: FadeCurve

    var body: some View {
        let composed = composedText
        let end = Date(timeIntervalSinceReferenceDate: curve.endTime(of: arrivals))

        TimelineView(FadeSchedule(end: end)) { context in
            composed.textRenderer(FadeInRenderer(
                now: context.date.timeIntervalSinceReferenceDate,
                curve: curve
            ))
        }
    }

    /// The text cut at its arrivals, each stretch tagged with its arrival
    /// time. Walks the characters once, however many arrivals there are.
    private var composedText: Text {
        let characters = text.characters
        var result = Text(verbatim: "")
        var lower = characters.startIndex

        for stretch in FadeCurve.stretches(of: arrivals, characterCount: characters.count) {
            let upper = characters.index(lower, offsetBy: stretch.range.count)
            let piece = Text(AttributedString(text[lower..<upper]))
            if let time = stretch.arrivalTime {
                result = result + piece.customAttribute(ArrivalAttribute(time: time))
            } else {
                result = result + piece
            }
            lower = upper
        }
        return result
    }
}

@available(iOS 18.0, *)
private struct ArrivalAttribute: TextAttribute {
    let time: TimeInterval
}

/// Draws each glyph with the opacity ``FadeCurve`` gives its age.
@available(iOS 18.0, *)
private struct FadeInRenderer: TextRenderer {

    var now: TimeInterval
    var curve: FadeCurve

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let arrival = run[ArrivalAttribute.self]?.time,
                      !curve.isComplete(age: now - arrival, length: run.count)
                else {
                    context.draw(run)
                    continue
                }
                for (index, glyph) in run.enumerated() {
                    var faded = context
                    faded.opacity = curve.opacity(age: now - arrival, glyphIndex: index)
                    faded.draw(glyph)
                }
            }
        }
    }
}
