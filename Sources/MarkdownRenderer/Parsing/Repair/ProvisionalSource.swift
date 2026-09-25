import Foundation

/// What cmark is shown while the stream is still arriving: the window, with
/// the text after its last blank line (or closing fence) repaired.
///
/// The repairs run in a fixed order, and the order matters:
///
/// 1. ``MarkerWithholding`` drops a last line that is only a block marker, so
///    the later steps never see it.
/// 2. ``IncompleteLinkRepair`` reduces a half-arrived link to its label
///    before delimiters are balanced, so a `**` inside the label is closed
///    inside the label.
/// 3. ``InlineDelimiterRepair`` closes dangling `**`, `_`, `~~` and backticks.
/// 4. ``TableCompletion`` runs last, so a closer that step 3 appended lands in
///    the header line rather than after the synthesised delimiter row.
///
/// Inside an open fence only a half-typed closing fence is withheld: the
/// contents of a fence are literal and are never repaired.
enum ProvisionalSource {

    static func make(from window: String, scan: WindowScan, repairs: MarkdownStreamingOptions.Repairs) -> String {
        guard !repairs.isEmpty else { return window }

        if let fence = scan.openFence {
            guard repairs.contains(.withholdMarkers) else { return window }
            return MarkerWithholding.withholdingPartialClosingFence(fence, in: window)
        }

        var tail = String(window[scan.repairStart...])
        if repairs.contains(.withholdMarkers) {
            tail = MarkerWithholding.apply(to: tail)
        }
        if repairs.contains(.hideIncompleteLinks) {
            tail = IncompleteLinkRepair.apply(to: tail)
        }
        if repairs.contains(.closeInlineDelimiters) {
            tail = InlineDelimiterRepair.apply(to: tail)
        }
        if repairs.contains(.completeTables) {
            tail = TableCompletion.apply(to: tail)
        }
        return window[..<scan.repairStart] + tail
    }
}
