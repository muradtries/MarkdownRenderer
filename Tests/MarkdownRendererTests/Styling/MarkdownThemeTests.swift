import SwiftUI
import Testing
@testable import MarkdownRenderer

@Suite("MarkdownTheme")
struct MarkdownThemeTests {

    @Test("Heading fonts clamp to the declared levels")
    func headingFonts() {
        var theme = MarkdownTheme()
        theme.headingFonts = [.largeTitle, .title, .title2]
        #expect(theme.headingFont(level: 1) == .largeTitle)
        #expect(theme.headingFont(level: 3) == .title2)
        #expect(theme.headingFont(level: 6) == .title2)
        #expect(theme.headingFont(level: 0) == .largeTitle)
        #expect(theme.headingFont(level: -5) == .largeTitle)
    }

    @Test("An empty heading font list falls back to the body font")
    func headingFontFallback() {
        var theme = MarkdownTheme()
        theme.headingFonts = []
        theme.bodyFont = .callout
        #expect(theme.headingFont(level: 1) == .callout)
    }

    @Test("Heading top padding clamps and defaults to zero")
    func headingTopPadding() {
        var theme = MarkdownTheme()
        theme.headingTopPadding = [10, 4]
        #expect(theme.headingTopPadding(level: 1) == 10)
        #expect(theme.headingTopPadding(level: 2) == 4)
        #expect(theme.headingTopPadding(level: 5) == 4)

        theme.headingTopPadding = []
        #expect(theme.headingTopPadding(level: 1) == 0)
    }

    @Test("Bullet glyphs clamp to the deepest declared level and default to a bullet")
    func bulletGlyphs() {
        var theme = MarkdownTheme()
        theme.bulletGlyphs = ["-", "+"]
        #expect(theme.bulletGlyph(level: 0) == "-")
        #expect(theme.bulletGlyph(level: 1) == "+")
        #expect(theme.bulletGlyph(level: 7) == "+")

        theme.bulletGlyphs = []
        #expect(theme.bulletGlyph(level: 0) == "•")
    }

    @Test("Defaults keep the fade short enough for the parser's default retention")
    func fadeFitsRetention() {
        let theme = MarkdownTheme()
        let lineOfGlyphs = 60.0
        let longestFade = theme.fadeInDuration + theme.fadeInStagger * lineOfGlyphs
        #expect(longestFade < MarkdownStreamingOptions().arrivalRetention)
    }

    @Test("Themes are value-equatable")
    func equality() {
        var changed = MarkdownTheme()
        #expect(changed == MarkdownTheme())
        changed.blockSpacing += 1
        #expect(changed != MarkdownTheme())
    }
}
