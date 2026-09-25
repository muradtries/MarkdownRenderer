import SwiftUI

struct ContentView: View {

    enum Demo: Hashable { case streaming, chats, styling }

    /// `--chats` or `--styling` opens that tab, for screenshots.
    @State private var demo: Demo = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--chats") || arguments.contains("--open-chat") { return .chats }
        if arguments.contains("--styling") { return .styling }
        return .streaming
    }()

    var body: some View {
        TabView(selection: $demo) {
            StreamingDemoView()
                .tabItem { Label("Streaming", systemImage: "text.line.first.and.arrowtriangle.forward") }
                .tag(Demo.streaming)

            ChatsView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                .tag(Demo.chats)

            StylingDemoView()
                .tabItem { Label("Styling", systemImage: "paintpalette") }
                .tag(Demo.styling)
        }
    }
}

#Preview {
    ContentView()
}
