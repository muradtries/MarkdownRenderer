import SwiftUI

extension View {

    /// Opens the scroll view at its end rather than scrolling there once it
    /// is on screen.
    func startsAtBottom(proxy: ScrollViewProxy, anchorID: String) -> some View {
        modifier(StartsAtBottom(proxy: proxy, anchorID: anchorID))
    }

    /// Whether the end of the content is on screen. Only ever read, never
    /// acted on with a scroll, so it cannot feed back into the geometry it
    /// measures.
    func trackBottomVisibility(_ isAtBottom: Binding<Bool>) -> some View {
        modifier(TrackBottomVisibility(isAtBottom: isAtBottom))
    }

    /// Below iOS 18, the anchor at the end of the content reports its own
    /// visibility to `trackBottomVisibility`.
    func reportBottomVisibility(in coordinateSpace: String, containerHeight: CGFloat) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: BottomVisibilityKey.self,
                    value: geometry.frame(in: .named(coordinateSpace)).minY <= containerHeight + 12
                )
            }
        )
    }

    /// Whether the user's finger is moving the content, as opposed to a
    /// programmatic scroll.
    func trackDragging(_ isDragging: Binding<Bool>) -> some View {
        modifier(TrackDragging(isDragging: isDragging))
    }
}

private struct StartsAtBottom: ViewModifier {

    let proxy: ScrollViewProxy
    let anchorID: String

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.defaultScrollAnchor(.bottom, for: .initialOffset)
        } else {
            content.onAppear { proxy.scrollTo(anchorID, anchor: .bottom) }
        }
    }
}

/// `visibleRect` spans the content insets, so the bottom inset (the
/// composer) is trimmed off to get the lowest point actually uncovered.
private struct TrackBottomVisibility: ViewModifier {

    @Binding var isAtBottom: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.visibleRect.maxY - geometry.contentInsets.bottom >= geometry.contentSize.height - 12
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
        } else {
            content.onPreferenceChange(BottomVisibilityKey.self) { isVisible in
                isAtBottom = isVisible
            }
        }
    }
}

/// A lazy stack does not realise an anchor far out of view, which reads as
/// `false` — the right answer.
private struct BottomVisibilityKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// `@GestureState` resets even when the scroll view takes the gesture over,
/// which a plain `onEnded` does not guarantee.
private struct TrackDragging: ViewModifier {

    @Binding var isDragging: Bool
    @GestureState private var isTouching = false

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                isDragging = phase == .interacting
            }
        } else {
            content
                .simultaneousGesture(DragGesture().updating($isTouching) { _, state, _ in state = true })
                .onChange(of: isTouching) { isDragging = $0 }
        }
    }
}
