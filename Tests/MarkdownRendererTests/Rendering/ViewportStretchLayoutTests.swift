import SwiftUI
import Testing
import UIKit
@testable import MarkdownRenderer

/// The table's one-copy layout relies on two things SwiftUI does: a
/// horizontal scroll view's ideal width is its content's, and content can be
/// widened to the viewport at placement without reporting that width. These
/// tests pin both down in a hosted view, so an SDK change that breaks them
/// shows up here rather than as a table that fills every bubble.
@MainActor
@Suite("Viewport stretch")
struct ViewportStretchLayoutTests {

    @Test("Content narrower than the viewport keeps its natural ideal width but is placed as wide as the viewport")
    func narrowContentStretches() throws {
        guard #available(iOS 17.0, *) else { return }
        let record = try #require(layOut(contentWidth: 150, viewport: 320))
        #expect(record.ideal == 150)
        #expect(record.placedWidth == 320)
    }

    @Test("Content wider than the viewport keeps its width and scrolls")
    func wideContentScrolls() throws {
        guard #available(iOS 17.0, *) else { return }
        let record = try #require(layOut(contentWidth: 500, viewport: 320))
        #expect(record.ideal == 500)
        #expect(record.placedWidth == 500)
    }

    // MARK: Hosting

    final class Record: @unchecked Sendable {
        var ideal: CGFloat?
        var placedWidth: CGFloat?
    }

    /// Reports the scroll view's ideal width, as ``BlockStackLayout`` asks
    /// for it.
    private struct IdealWidth: Layout {
        let record: Record
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
            record.ideal = subviews[0].sizeThatFits(.unspecified).width
            return subviews[0].sizeThatFits(proposal)
        }
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
            subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }

    /// Stands in for the grid: a fixed natural width, recording the width it
    /// is placed at.
    private struct Content: Layout {
        let width: CGFloat
        let record: Record
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
            CGSize(width: max(width, proposal.width ?? 0), height: 20)
        }
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
            record.placedWidth = bounds.width
        }
    }

    @available(iOS 17.0, *)
    private func layOut(contentWidth: CGFloat, viewport: CGFloat) -> Record? {
        let record = Record()
        let view = IdealWidth(record: record) {
            ScrollView(.horizontal) {
                ViewportStretchLayout {
                    Color.clear.frame(height: 0).containerRelativeFrame(.horizontal)
                    Content(width: contentWidth, record: record) { Color.clear }
                }
            }
        }
        .frame(width: viewport)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        return record
    }
}
