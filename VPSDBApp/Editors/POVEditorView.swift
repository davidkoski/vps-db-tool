import SwiftUI
import VPSDB

/// Create or edit a ``POV`` for a single game.
///
/// Only has the common fields -- see ``ResourceEditor``.
struct POVEditorView: View {
    @Binding var db: Database
    /// The source page when creating -- `nil` when editing an existing resource.
    var detail: DetailResult? = nil
    let games: [Game]
    let client: HTTPClient
    var pov: POV? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    var body: some View {
        ResourceEditor(
            db: $db, detail: detail, games: games, client: client,
            resource: pov, onDone: onDone)
    }
}

#Preview {
    NavigationStack {
        POVEditorView(
            db: .constant(Database()),
            detail: DetailResult(
                .list,
                url: URL(string: "https://vpuniverse.com/files/file/1234")!,
                kind: .pov, name: "Example", author: "Someone", version: "1.0"),
            games: [Game(name: "Example")],
            client: HTTPClient(),
            onDone: { _ in }
        )
    }
}
