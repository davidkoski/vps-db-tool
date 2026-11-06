import SwiftUI
import VPSDB

/// Create or edit a ``AltSound`` for a single game.
///
/// Only has the common fields -- see ``ResourceEditor``.
struct AltSoundEditorView: View {
    @Binding var db: Database
    /// The source page when creating -- `nil` when editing an existing resource.
    var detail: DetailResult? = nil
    let games: [Game]
    let client: HTTPClient
    var altSound: AltSound? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    var body: some View {
        ResourceEditor(
            db: $db, detail: detail, games: games, client: client,
            resource: altSound, onDone: onDone)
    }
}

#Preview {
    NavigationStack {
        AltSoundEditorView(
            db: .constant(Database()),
            detail: DetailResult(
                .list,
                url: URL(string: "https://vpuniverse.com/files/file/1234")!,
                kind: .altSound, name: "Example", author: "Someone", version: "1.0"),
            games: [Game(name: "Example")],
            client: HTTPClient(),
            onDone: { _ in }
        )
    }
}
