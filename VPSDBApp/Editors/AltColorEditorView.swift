import SwiftUI
import VPSDB

/// Create or edit an ``AltColors`` for a single game.
///
/// Adds the type, file name and folder to the common fields -- see
/// ``ResourceEditor``.
struct AltColorEditorView: View {
    @Binding var db: Database
    /// The source page when creating -- `nil` when editing an existing resource.
    var detail: DetailResult? = nil
    let games: [Game]
    let client: HTTPClient
    var altColor: AltColors? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    /// Known alt color types, for completion.
    @State private var types = Lazy { ["Pin2DMD", "Serum", "Serum 2"] }

    var body: some View {
        ResourceEditor(
            db: $db, detail: detail, games: games, client: client,
            resource: altColor, onDone: onDone
        ) { altColor, _ in
            Section("Alt Color") {
                LabeledContent("Type") {
                    CompletingTextField(
                        title: "Type", text: altColor.type.orEmpty, candidates: types
                    )
                    .labelsHidden()
                }
                TextField("File Name", text: altColor.fileName.orEmpty)
                TextField("Folder", text: altColor.folder.orEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AltColorEditorView(
            db: .constant(Database()),
            detail: DetailResult(
                .list,
                url: URL(string: "https://vpuniverse.com/files/file/1234")!,
                kind: .altColor, name: "Example", author: "Someone", version: "1.0"),
            games: [Game(name: "Example")],
            client: HTTPClient(),
            onDone: { _ in }
        )
    }
}
