import SwiftUI

/// A list of past conversations, as in any chat app. Tapping one loads its
/// history and opens it already scrolled to the latest message.
struct ChatsView: View {

    /// A pushed chat; `autosend` is a message sent once its history is loaded.
    private struct Route: Hashable {
        var id: Conversation.ID
        var autosend: String?
    }

    @StateObject private var store = ConversationStore()
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(store.conversations) { conversation in
                NavigationLink(value: Route(id: conversation.id)) {
                    ConversationRow(conversation: conversation)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(Route(id: store.startNew().id))
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                if let conversation = store.conversation(id: route.id) {
                    ChatView(conversation: conversation, store: store, autosend: route.autosend)
                }
            }
        }
        .task { openFromLaunchArguments() }
    }

    /// `--open-chat <index>` pushes a conversation on launch, and `--autosend`
    /// sends a message in it once loaded, for screenshots.
    private func openFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard path.isEmpty,
              let flag = arguments.firstIndex(of: "--open-chat"),
              let index = arguments.dropFirst(flag + 1).first.flatMap({ Int($0) }),
              store.conversations.indices.contains(index)
        else { return }

        let autosend = arguments.contains("--autosend") ? "And how do I keep the bottom in view while the reply streams?" : nil
        path = [Route(id: store.conversations[index].id, autosend: autosend)]
    }
}

private struct ConversationRow: View {

    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(conversation.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ChatsView()
}
