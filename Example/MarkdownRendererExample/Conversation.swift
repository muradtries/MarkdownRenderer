import Foundation

/// A conversation as it would come back from a backend or a database: raw
/// markdown per turn, nothing parsed. Parsing happens when a chat is opened.
struct Conversation: Identifiable, Hashable, Sendable {

    struct Turn: Hashable, Sendable {
        enum Role: Hashable, Sendable { case user, assistant }

        var role: Role
        var text: String
    }

    let id: UUID
    var title: String
    var updatedAt: Date
    var turns: [Turn]

    init(id: UUID = UUID(), title: String, updatedAt: Date, turns: [Turn]) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.turns = turns
    }

    /// The first prose line of the last turn with its markdown stripped, for
    /// the list row. Table rows, fences and rules are skipped.
    var preview: String {
        guard let last = turns.last else { return "No messages yet" }
        let line = last.text
            .split(separator: "\n")
            .map { Self.stripBlockMarkers(from: String($0)) }
            .first { !$0.isEmpty && !$0.hasPrefix("|") && !$0.hasPrefix("```") && !$0.allSatisfy { $0 == "-" } } ?? ""
        let plain = (try? AttributedString(markdown: line)).map { String($0.characters) } ?? line
        return last.role == .user ? "You: \(plain)" : plain
    }

    private static func stripBlockMarkers(from line: String) -> String {
        var text = line.drop { "#> ".contains($0) }
        if let marker = ["- [x] ", "- [ ] ", "- ", "* "].first(where: { text.hasPrefix($0) }) {
            text = text.dropFirst(marker.count)
        }
        return String(text)
    }
}

/// Every conversation the Chats tab lists. Chats write their turns back here
/// when a reply finishes, so reopening one shows what was sent.
@MainActor
final class ConversationStore: ObservableObject {

    static let newChatTitle = "New chat"

    @Published private(set) var conversations: [Conversation] = SampleConversations.all

    func conversation(id: Conversation.ID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func startNew() -> Conversation {
        let conversation = Conversation(title: Self.newChatTitle, updatedAt: .now, turns: [])
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func save(_ turns: [Conversation.Turn], to id: Conversation.ID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }),
              conversations[index].turns != turns
        else { return }

        var conversation = conversations.remove(at: index)
        conversation.turns = turns
        conversation.updatedAt = .now
        if conversation.title == Self.newChatTitle, let prompt = turns.first(where: { $0.role == .user }) {
            conversation.title = String(prompt.text.prefix(40))
        }
        conversations.insert(conversation, at: 0)
    }
}
