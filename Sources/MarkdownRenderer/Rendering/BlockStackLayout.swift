import SwiftUI

/// Stacks a message's blocks top to bottom, as wide as its content rather
/// than as wide as it is offered, the way `Text` sizes itself.
///
/// A `VStack` is as wide as its widest child, but a divider, a horizontally
/// scrolling table or a block framed with `maxWidth: .infinity` is as wide as
/// whatever it is offered, which would make every message fill its bubble.
/// So a block that fills the offered width counts with its ideal width
/// instead, and is then laid out at the width the other blocks set: a
/// divider or a table follows the text instead of setting the width.
///
/// Every block is asked for its size once, at the offered width, as a `VStack`
/// would. Only a block that fills that width is asked again, for its ideal
/// width, and only while the width is still undecided. A block that hugs its
/// content is placed with the same proposal it was measured with, so SwiftUI
/// reuses the measurement and text is never laid out twice. Nothing is cached
/// across passes: a block's size can change without the stack's subviews
/// changing (a custom builder's own state, for one), and SwiftUI already
/// caches each subview's answer per proposal.
struct BlockStackLayout: Layout {

    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let blocks = measure(offered: proposal.width, subviews: subviews)
        return CGSize(width: blocks.width, height: blocks.heights.reduce(0, +) + totalSpacing(subviews.count))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let blocks = measure(offered: proposal.width, subviews: subviews)
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let width = blocks.fills[index] ? bounds.width : blocks.offered
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: nil)
            )
            y += blocks.heights[index] + spacing
        }
    }

    private struct Blocks {
        /// The width each block was first measured at: the offered width, or
        /// `nil` when none was offered.
        var offered: CGFloat?
        var width: CGFloat
        var heights: [CGFloat]
        /// Which blocks fill whatever width they are offered, and so are laid
        /// out at the stack's width rather than at `offered`.
        var fills: [Bool]
    }

    private func measure(offered: CGFloat?, subviews: Subviews) -> Blocks {
        let available = offered.flatMap { $0.isFinite ? $0 : nil }
        let proposal = ProposedViewSize(width: available, height: nil)
        let sizes = subviews.map { $0.sizeThatFits(proposal) }
        let fills = sizes.map { available != nil && $0.width >= available! }

        let width = Self.contentWidth(
            available: available,
            fitted: sizes.map(\.width),
            ideal: { subviews[$0].sizeThatFits(.unspecified).width }
        )

        let heights = sizes.indices.map { index in
            guard fills[index], width != available else { return sizes[index].height }
            return subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return Blocks(offered: available, width: width, heights: heights, fills: fills)
    }

    private func totalSpacing(_ count: Int) -> CGFloat {
        spacing * CGFloat(max(0, count - 1))
    }

    /// The width of the stack: the widest block, where a block that fills
    /// the available width counts with its ideal width instead, all capped
    /// at `available`. A block narrower than `available` already shows its
    /// natural or wrapped width, which is never more than its ideal one, so
    /// `ideal` is asked only of blocks that fill, and not at all once the
    /// width has reached `available`. With nothing available the fitted
    /// widths are the ideal ones.
    static func contentWidth(available: CGFloat?, fitted: [CGFloat], ideal: (Int) -> CGFloat) -> CGFloat {
        guard let available else { return fitted.max() ?? 0 }

        var width: CGFloat = 0
        var filling: [Int] = []
        for (index, fittedWidth) in fitted.enumerated() {
            if fittedWidth < available {
                width = max(width, fittedWidth)
            } else {
                filling.append(index)
            }
        }
        for index in filling where width < available {
            width = max(width, min(available, ideal(index)))
        }
        return width
    }
}
