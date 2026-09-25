import MarkdownRenderer
import SwiftUI

struct ChatMessage: Identifiable, Equatable, Sendable {

    let id: UUID
    var role: Conversation.Turn.Role
    var text: String
    var blocks: [MarkdownBlock]
    var isStreaming: Bool

    init(role: Conversation.Turn.Role, text: String, blocks: [MarkdownBlock] = [], isStreaming: Bool = false) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.blocks = blocks
        self.isStreaming = isStreaming
    }

    /// A finished turn from history: parsed in one shot, no streaming parser.
    init(turn: Conversation.Turn) {
        let blocks = turn.role == .assistant ? IncrementalMarkdownParser.blocks(parsing: turn.text) : []
        self.init(role: turn.role, text: turn.text, blocks: blocks)
    }

    var turn: Conversation.Turn {
        Conversation.Turn(role: role, text: text)
    }
}

/// One open conversation: its history, parsed off the main thread when the
/// chat opens, plus at most one reply streaming into it.
@MainActor
final class ChatThread: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var isStreaming = false

    /// Bumped on every flush of the streaming reply, so the view can follow
    /// it without comparing blocks.
    @Published private(set) var revision = 0

    private let conversationID: Conversation.ID
    private let store: ConversationStore
    private var pendingPrompt: String?
    private var replyTask: Task<Void, Never>?

    init(conversationID: Conversation.ID, store: ConversationStore, autosend: String? = nil) {
        self.conversationID = conversationID
        self.store = store
        self.pendingPrompt = autosend
    }

    func load() async {
        if !isLoaded {
            let turns = store.conversation(id: conversationID)?.turns ?? []
            messages = await Task.detached(priority: .userInitiated) {
                turns.map(ChatMessage.init(turn:))
            }.value
            isLoaded = true
        }

        guard let prompt = pendingPrompt,
              (try? await Task.sleep(for: .seconds(1))) != nil
        else { return }
        pendingPrompt = nil
        send(prompt)
    }

    func send(_ prompt: String) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        let reply = SampleConversations.reply(forMessageAt: messages.filter { $0.role == .user }.count)
        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        isStreaming = true

        let index = messages.count - 1
        replyTask = Task { [weak self] in
            await self?.stream(reply, into: index)
        }
    }

    /// Keeps whatever already arrived; the partial reply is saved like a
    /// finished one.
    func stop() {
        replyTask?.cancel()
    }

    private func stream(_ markdown: String, into index: Int) async {
        let parser = IncrementalMarkdownParser()
        let pace = StreamPace.fast

        if (try? await Task.sleep(for: .milliseconds(450))) != nil {
            for token in SampleMarkdown.tokens(of: markdown) {
                guard (try? await Task.sleep(for: pace.interval)) != nil else { break }
                apply(await parser.append(token), at: index)
            }
        }
        apply(await parser.finish(), at: index)

        if messages.indices.contains(index) { messages[index].isStreaming = false }
        isStreaming = false
        replyTask = nil
        store.save(messages.filter { !$0.text.isEmpty }.map(\.turn), to: conversationID)
    }

    private func apply(_ snapshot: IncrementalMarkdownParser.Snapshot, at index: Int) {
        guard messages.indices.contains(index) else { return }
        messages[index].blocks = snapshot.blocks
        messages[index].text = snapshot.rawText
        revision += 1
    }
}

/// A chat screen with history. It opens at the latest message, sending
/// always brings the bottom into view, and a streaming reply is followed
/// until the reader drags away; scrolling back to the bottom resumes it.
struct ChatView: View {

    @StateObject private var thread: ChatThread
    @State private var draft = ""
    @State private var isFollowing = true
    @State private var isAtBottom = true
    @State private var isDragging = false

    private let title: String
    private let bottomAnchorID = "chat.bottom"
    private let coordinateSpaceName = "chat.transcript"

    init(conversation: Conversation, store: ConversationStore, autosend: String? = nil) {
        title = conversation.title
        _thread = StateObject(wrappedValue: ChatThread(conversationID: conversation.id, store: store, autosend: autosend))
    }

    var body: some View {
        Group {
            if thread.isLoaded {
                transcript
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await thread.load() }
        .onDisappear { thread.stop() }
    }

    // MARK: - Transcript

    /// Rendered only once the history is loaded, so the initial bottom anchor
    /// applies to the full transcript rather than to an empty one.
    private var transcript: some View {
        ScrollViewReader { proxy in
            GeometryReader { container in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if thread.messages.isEmpty {
                            emptyState
                        }
                        ForEach(thread.messages) { message in
                            MessageRow(message: message)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                            .reportBottomVisibility(in: coordinateSpaceName, containerHeight: container.size.height)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .coordinateSpace(name: coordinateSpaceName)
                .scrollDismissesKeyboard(.interactively)
                .startsAtBottom(proxy: proxy, anchorID: bottomAnchorID)
                .trackBottomVisibility($isAtBottom)
                .trackDragging($isDragging)
                .onChange(of: thread.messages.count) { _ in
                    isFollowing = true
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: thread.revision) { _ in
                    guard isFollowing else { return }
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
                .onChange(of: container.size.height) { _ in
                    guard isFollowing else { return }
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
                .onChange(of: isDragging) { dragging in
                    isFollowing = !dragging && isAtBottom
                }
                .onChange(of: isAtBottom) { atBottom in
                    guard atBottom, !isDragging else { return }
                    isFollowing = true
                }
                .overlay(alignment: .bottom) {
                    if showsScrollToBottom {
                        scrollToBottomButton(proxy)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: showsScrollToBottom)
            }
        }
    }

    private var showsScrollToBottom: Bool {
        !isFollowing && !isAtBottom
    }

    private var emptyState: some View {
        Text("Ask anything — replies are canned markdown, streamed token by token.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    private func scrollToBottomButton(_ proxy: ScrollViewProxy) -> some View {
        Button {
            isFollowing = true
            withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scroll to bottom")
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

            Button {
                if thread.isStreaming {
                    thread.stop()
                } else {
                    thread.send(draft)
                    draft = ""
                }
            } label: {
                Image(systemName: thread.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!thread.isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(thread.isStreaming ? "Stop" : "Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .disabled(!thread.isLoaded)
    }
}

// MARK: - Messages

private struct MessageRow: View, Equatable {

    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 44)
                Text(message.text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
            }
        case .assistant:
            if message.isStreaming && message.blocks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MarkdownMessageView(blocks: message.blocks)
            }
        }
    }
}
