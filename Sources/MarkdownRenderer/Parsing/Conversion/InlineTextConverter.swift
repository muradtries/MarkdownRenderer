import Foundation
import Markdown

/// Turns swift-markdown inline content into an `AttributedString`.
///
/// Runs carry semantic attributes only: `inlinePresentationIntent` for
/// strong, emphasis, code and strikethrough, and `link` for links. SwiftUI's
/// `Text` draws all four intents itself, in the size and weight of the
/// surrounding font, so the model stays free of fonts and colours;
/// ``MarkdownText`` adds only what `Text` does not (code background, link
/// underline).
enum InlineTextConverter {

    static func text(of container: any Markup) -> AttributedString {
        var builder = InlineTextBuilder()
        appendChildren(of: container, to: &builder, attributes: InlineTextBuilder.Attributes())
        return builder.build()
    }

    static func plainText(of markup: any Markup) -> String? {
        (markup as? any PlainTextConvertibleMarkup)?.plainText
    }

    /// Walks the inline children, accumulating attributes through nesting so
    /// `***both***` ends up with strong and emphasis on the same run.
    private static func appendChildren(
        of container: any Markup,
        to builder: inout InlineTextBuilder,
        attributes: InlineTextBuilder.Attributes
    ) {
        for child in container.children {
            switch child {
            case let text as Markdown.Text:
                builder.append(text.string, attributes)
            case let code as InlineCode:
                builder.append(code.code, attributes.adding(.code))
            case let strong as Strong:
                appendChildren(of: strong, to: &builder, attributes: attributes.adding(.stronglyEmphasized))
            case let emphasis as Emphasis:
                appendChildren(of: emphasis, to: &builder, attributes: attributes.adding(.emphasized))
            case let strikethrough as Strikethrough:
                appendChildren(of: strikethrough, to: &builder, attributes: attributes.adding(.strikethrough))
            case let link as Link:
                let url = link.destination.flatMap(URL.init(string:))
                appendChildren(of: link, to: &builder, attributes: attributes.linking(to: url))
            case let image as Image:
                appendChildren(of: image, to: &builder, attributes: attributes)
            case is SoftBreak:
                builder.append(" ", attributes)
            case is LineBreak:
                builder.append("\n", attributes)
            case let html as InlineHTML:
                builder.append(html.rawHTML, attributes)
            case let nested as any InlineContainer:
                appendChildren(of: nested, to: &builder, attributes: attributes)
            default:
                if let plain = plainText(of: child) {
                    builder.append(plain, attributes)
                }
            }
        }
    }
}

/// Collects inline text as a plain string plus a list of attribute runs, and
/// makes the `AttributedString` once at the end.
///
/// Appending to an `AttributedString` piece by piece costs more the longer it
/// gets, which made a paragraph with a thousand bold words take milliseconds
/// to convert. Setting attributes over ranges of one finished string does
/// not.
struct InlineTextBuilder {

    struct Attributes: Equatable {
        var intent: InlinePresentationIntent = []
        var link: URL?

        func adding(_ intent: InlinePresentationIntent) -> Attributes {
            Attributes(intent: self.intent.union(intent), link: link)
        }

        func linking(to url: URL?) -> Attributes {
            Attributes(intent: intent, link: url ?? link)
        }
    }

    private struct Run {
        var scalarCount: Int
        var attributes: Attributes
    }

    private var string = ""
    private var runs: [Run] = []

    mutating func append(_ text: String, _ attributes: Attributes) {
        guard !text.isEmpty else { return }
        string += text
        let scalarCount = text.unicodeScalars.count
        if let last = runs.indices.last, runs[last].attributes == attributes {
            runs[last].scalarCount += scalarCount
        } else {
            runs.append(Run(scalarCount: scalarCount, attributes: attributes))
        }
    }

    func build() -> AttributedString {
        var result = AttributedString(string)
        var lower = result.startIndex
        for run in runs {
            let upper = result.unicodeScalars.index(lower, offsetBy: run.scalarCount)
            if !run.attributes.intent.isEmpty {
                result[lower..<upper].inlinePresentationIntent = run.attributes.intent
            }
            if let link = run.attributes.link {
                result[lower..<upper].link = link
            }
            lower = upper
        }
        return result
    }
}
