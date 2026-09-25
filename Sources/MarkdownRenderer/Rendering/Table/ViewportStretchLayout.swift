import SwiftUI

/// Content for a horizontal `ScrollView` that fills the scroll view's width
/// when it is narrower, without reporting that width as its own size.
///
/// Takes two subviews: a zero-height probe made as wide as the scroll view
/// with `containerRelativeFrame(.horizontal)`, and the content. Its size is
/// the content's natural size, so the scroll view's ideal width stays the
/// content's and scrolling starts exactly when the content is wider than the
/// viewport. Only when placing does it widen the content to the probe's
/// width, which lets a table stretch to the message's width with one copy of
/// its cells and no state.
@available(iOS 17.0, *)
struct ViewportStretchLayout: Layout {

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        return subviews[1].sizeThatFits(.unspecified)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard subviews.count == 2 else { return }
        let viewport = subviews[0].sizeThatFits(.unspecified).width
        subviews[0].place(at: bounds.origin, proposal: .zero)
        subviews[1].place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: max(viewport, bounds.width), height: bounds.height)
        )
    }
}
