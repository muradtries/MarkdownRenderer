import Foundation

/// One item of a list block. Nested lists are flattened: an item's `level`
/// says how deep it sits, and its nested items follow it in the list.
public struct MarkdownListItem: Equatable, Sendable {

    /// Nesting depth, 0 for top level.
    public var level: Int

    /// The item's number in an ordered list, `nil` for a bullet.
    public var number: Int?

    /// `true` for `- [x]`, `false` for `- [ ]`, `nil` for an item that is not
    /// a task.
    public var isChecked: Bool?

    /// The item's inline content. Paragraphs of a loose item are joined with
    /// a space; code inside the item is joined with a newline.
    public var text: AttributedString

    public init(level: Int, number: Int? = nil, isChecked: Bool? = nil, text: AttributedString) {
        self.level = level
        self.number = number
        self.isChecked = isChecked
        self.text = text
    }
}
