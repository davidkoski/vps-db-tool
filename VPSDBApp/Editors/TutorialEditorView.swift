import SwiftUI
import VPSDB

/// Create or edit a ``Tutorial`` for a single game.
///
/// Tutorials don't come from a site scan -- they are added from a pasted URL
/// on the updates view (YouTube or any other page).
struct TutorialEditorView: View {
    @Binding var db: Database
    /// The source page when creating -- `nil` when editing an existing resource.
    var detail: DetailResult? = nil
    let games: [Game]
    let client: HTTPClient
    var tutorial: Tutorial? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    var body: some View {
        ResourceEditor(
            db: $db, detail: detail, games: games, client: client,
            resource: tutorial, onDone: onDone
        ) { tutorial, _ in
            Section("Tutorial") {
                TextField("Title", text: tutorial.title)

                HStack {
                    TextField("YouTube ID", text: tutorial.youtubeId.orEmpty)
                    if let id = tutorial.wrappedValue.youtubeId,
                        let url = URL(string: "https://www.youtube.com/watch?v=\(id)")
                    {
                        OpenURLButton(url: url)
                    }
                }

                HStack {
                    TextField("URL", text: tutorial.url.text)
                    if let url = tutorial.wrappedValue.url {
                        OpenURLButton(url: url)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TutorialEditorView(
            db: .constant(Database()),
            detail: DetailResult(
                .list,
                url: URL(string: "https://www.youtube.com/watch?v=afIOXq040dM")!,
                kind: .tutorial, name: "Example", author: "Someone"),
            games: [Game(name: "Example")],
            client: HTTPClient(),
            onDone: { _ in }
        )
    }
}
