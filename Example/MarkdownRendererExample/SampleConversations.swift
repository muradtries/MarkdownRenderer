import Foundation

/// Canned history for the Chats tab, long enough that opening a chat at the
/// top would be the wrong place to land.
enum SampleConversations {

    static let all: [Conversation] = [
        Conversation(
            title: "Streaming markdown in SwiftUI",
            updatedAt: .now.addingTimeInterval(-12 * 60),
            turns: [
                .init(role: .user, text: "Why does my chat view stutter when the model streams a long answer?"),
                .init(role: .assistant, text: """
                Almost always because **every token re-renders the whole message**. A few things compound:

                - the full response is re-parsed on each token, so the cost is *O(n²)*
                - every view in the message body is invalidated, not just the last paragraph
                - `Text` with a fresh `AttributedString` re-lays out from scratch

                How are you parsing today — `AttributedString(markdown:)` on the whole string?
                """),
                .init(role: .user, text: "Yes, on every chunk. The whole thing."),
                .init(role: .assistant, text: SampleMarkdown.document),
                .init(role: .user, text: "What about scrolling? Right now I call `scrollTo` on every token."),
                .init(role: .assistant, text: """
                That part is fine, as long as you only do it **while the reader is following**. The rules most chat apps use:

                1. Sending a message always scrolls to the bottom
                2. While a reply streams, keep the bottom in view — unless the user drags away
                3. Scrolling back down to the bottom resumes following
                4. When not following, show a small *scroll to bottom* button instead

                > Never yank the transcript out from under someone who is reading an earlier answer.

                Opening an existing conversation is a separate case: land **already at the bottom**, without an animated scroll through the history.
                """),
                .init(role: .user, text: "How do I open it already at the bottom without a visible jump?"),
                .init(role: .assistant, text: """
                On iOS 18 there is a modifier for exactly this:

                ```swift
                ScrollView { transcript }
                    .defaultScrollAnchor(.bottom, for: .initialOffset)
                ```

                It sets the *initial* offset only, so content that grows later is still yours to manage. Below iOS 18, call `scrollTo` without animation in `onAppear`.

                | iOS | Initial position | Following |
                | --- | --- | --- |
                | 16–17 | `scrollTo` in `onAppear` | `scrollTo` per flush |
                | 18+ | `defaultScrollAnchor(_:for:)` | `scrollTo` per flush |

                Render the scroll view only **after** the history is loaded, or the anchor applies to an empty transcript.
                """),
            ]
        ),
        Conversation(
            title: "Actors vs. locks",
            updatedAt: .now.addingTimeInterval(-3 * 3600),
            turns: [
                .init(role: .user, text: "When should I reach for an actor instead of a lock?"),
                .init(role: .assistant, text: """
                Use an **actor** when the protected state is touched from async code and callers can afford to `await`. Use a **lock** (`Mutex` on newer OSes, `OSAllocatedUnfairLock` before) when:

                - the critical section is tiny and synchronous
                - callers are synchronous and cannot suspend
                - you need the value *right now*, e.g. inside a property getter

                Actors also give you **reentrancy**: state can change across an `await` inside the actor. Locks never suspend, so they cannot be reentered that way.
                """),
                .init(role: .user, text: "And a global actor like `@MainActor`?"),
                .init(role: .assistant, text: """
                A global actor is for state that belongs to one *domain* spread across many types. `@MainActor` is the UI domain; a parser might get its own:

                ```swift
                @globalActor
                actor ParsingActor {
                    static let shared = ParsingActor()
                }
                ```

                Everything annotated with it shares one serial executor, so those types can call each other synchronously.
                """),
                .init(role: .user, text: "Is there a cost to hopping between them?"),
                .init(role: .assistant, text: """
                Each hop is a suspension and a possible thread switch — cheap, but not free. Batch work so that **one flush is one hop**: return a snapshot of everything the caller needs rather than making it `await` three properties in a row.
                """),
            ]
        ),
        Conversation(
            title: "Weekend in Lisbon",
            updatedAt: .now.addingTimeInterval(-26 * 3600),
            turns: [
                .init(role: .user, text: "Plan two relaxed days in Lisbon for someone who likes food and views."),
                .init(role: .assistant, text: """
                ## Day 1 — Alfama and the river

                - **Morning:** tram 28 up to *Miradouro de Santa Luzia*, then wander down through Alfama
                - **Lunch:** grilled sardines at a tasca near the cathedral
                - **Afternoon:** walk the riverfront to Praça do Comércio
                - **Evening:** fado dinner in Alfama — book ahead

                ## Day 2 — Belém and LX Factory

                1. Pastéis de Belém early, before the queue
                2. Jerónimos Monastery and the Belém Tower
                3. Lunch at LX Factory
                4. Sunset at *Miradouro da Senhora do Monte*
                """),
                .init(role: .user, text: "What would it roughly cost?"),
                .init(role: .assistant, text: """
                | Item | Per person |
                | --- | ---: |
                | Tram and metro day passes | €13 |
                | Two lunches | €35 |
                | Fado dinner | €60 |
                | Monastery entry | €12 |
                | Pastries and coffee | €10 |

                Roughly **€130** for the two days, not counting where you stay.
                """),
            ]
        ),
        Conversation(
            title: "Sourdough starter",
            updatedAt: .now.addingTimeInterval(-3 * 86400),
            turns: [
                .init(role: .user, text: "My starter smells like nail polish remover. Is it dead?"),
                .init(role: .assistant, text: """
                Not dead — **hungry**. That acetone smell means the yeast has run out of food and the bacteria are producing acetic compounds.

                - feed it at a higher ratio, e.g. 1:5:5 starter to flour to water
                - keep it somewhere warm, around 24–26 °C
                - after two or three feeds the smell should turn yoghurty again

                > A starter is remarkably hard to kill. Mould is the only real reason to throw one out.
                """),
                .init(role: .user, text: "Thanks! It doubled this morning."),
                .init(role: .assistant, text: "Then it is ready to bake with. Use it **at its peak**, when it has doubled and the top is just starting to dome."),
            ]
        ),
        Conversation(
            title: "Pull request checklist",
            updatedAt: .now.addingTimeInterval(-9 * 86400),
            turns: [
                .init(role: .user, text: "Give me a short checklist to run before opening a PR."),
                .init(role: .assistant, text: """
                - [x] The branch builds and the tests pass locally
                - [x] The diff contains only what the title says
                - [ ] New public API has doc comments
                - [ ] Screenshots for anything visual
                - [ ] The description says *why*, not just *what*

                ---

                Keep PRs small enough to review in **one sitting** — under ~400 changed lines is a good rule of thumb.
                """),
            ]
        ),
    ]

    /// Canned replies for new messages, cycled in order.
    static let replies: [String] = [
        """
        Good question. The short version: **it depends on where the cost is.**

        - measure first — Instruments' *SwiftUI* template shows which bodies run
        - then fix the hottest path, not the most suspicious one

        Want me to walk through a profile?
        """,
        SampleMarkdown.document,
        """
        ## A quick comparison

        | Approach | Good at | Watch out for |
        | --- | --- | --- |
        | Eager `VStack` | short transcripts | memory grows with history |
        | `LazyVStack` | long transcripts | estimated heights while scrolling |
        | `List` | cell reuse | styling, scroll control |

        For a chat, a `LazyVStack` in a `ScrollView` is the usual choice.
        """,
    ]

    static func reply(forMessageAt index: Int) -> String {
        replies[index % replies.count]
    }
}
