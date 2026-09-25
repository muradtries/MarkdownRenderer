import CoreGraphics
import Testing
@testable import MarkdownRenderer

@Suite("Block stack width")
struct BlockStackLayoutTests {

    @Test("Wrapped text sets the width")
    func textSetsWidth() {
        #expect(width(available: 300, fitted: [180, 240], ideal: [180, 900]) == 240)
    }

    @Test("A block that fills whatever it is offered does not widen the message")
    func fillingBlockFollows() {
        #expect(width(available: 300, fitted: [120, 300], ideal: [120, 8]) == 120)
    }

    @Test("A table that fits counts with its natural width")
    func fittingTable() {
        #expect(width(available: 300, fitted: [100, 300], ideal: [100, 160]) == 160)
    }

    @Test("A table wider than offered makes the message as wide as offered, no wider")
    func overflowingTable() {
        #expect(width(available: 300, fitted: [100, 300], ideal: [100, 700]) == 300)
    }

    @Test("With no width offered the stack is its widest ideal width")
    func unconstrained() {
        #expect(width(available: nil, fitted: [90, 400], ideal: [90, 400]) == 400)
    }

    @Test("An empty message has no width")
    func empty() {
        #expect(width(available: 300, fitted: [], ideal: []) == 0)
    }

    @Test("Only blocks that fill the offered width are asked for their ideal width")
    func idealAskedOnlyOfFillingBlocks() {
        var asked: [Int] = []
        let result = BlockStackLayout.contentWidth(available: 300, fitted: [120, 300, 90, 300]) { index in
            asked.append(index)
            return 50
        }
        #expect(result == 120)
        #expect(asked == [1, 3])
    }

    @Test("Once a block reaches the offered width, no ideal width is asked for")
    func idealSkippedAtFullWidth() {
        var asked: [Int] = []
        let result = BlockStackLayout.contentWidth(available: 300, fitted: [300, 120]) { index in
            asked.append(index)
            return 900
        }
        #expect(result == 300)
        #expect(asked == [0])
    }

    private func width(available: CGFloat?, fitted: [CGFloat], ideal: [CGFloat]) -> CGFloat {
        BlockStackLayout.contentWidth(available: available, fitted: fitted) { ideal[$0] }
    }
}
