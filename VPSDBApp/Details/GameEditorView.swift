import Logging
import SwiftUI
import VPSDB

private let log = Logger(label: "GameEditorView")

/// A section per kind (that the game has) listing the game's resources --
/// `row` builds each row.
struct GameResourcesSections<Row: View>: View {
    let game: Game
    @ViewBuilder let row: (GameResourceKind, any GameResource) -> Row

    var body: some View {
        ForEach(GameResourceKind.allCases.sorted().filter { $0 != .game }, id: \.self) { kind in
            let resources = game[kind].sorted { $0.createdAt < $1.createdAt }
            if !resources.isEmpty {
                Section("\(Text(kind.displayName)) (\(resources.count))") {
                    ForEach(resources, id: \.id) { resource in
                        row(kind, resource)
                    }
                }
            }
        }
    }
}

/// One line (plus comment) describing a resource: version, authors, date.
struct ResourceSummaryRow: View {
    let resource: any GameResource

    var body: some View {
        let common = resource.gameResource
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if let version = common.version, !version.isEmpty {
                    Text(version)
                        .monospacedDigit()
                }
                Text(common.authors.map(\.name).joined(separator: ", "))
                    .foregroundStyle(common.authors.isEmpty ? .tertiary : .primary)
                Spacer()
                if common.createdAt != .distantPast {
                    Text(common.createdAt, format: .dateTime.year().month().day())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let comment = common.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .help(resource.id)
    }
}

/// Edit a game's resources: open each in its editor, or delete it -- and move
/// resources here from other games, or merge other games into this one.
struct GameEditorView: View {
    @Binding var db: Database
    let gameId: String

    /// The navigation path -- resource editors are pushed onto it.
    @Binding var path: [KindRoute]

    /// The resource to delete, awaiting confirmation.
    @State private var pendingDelete: PendingDelete?
    @State private var error: String?

    /// IPDB entries, for the new game when splitting.
    @Environment(\.ipdb) private var ipdb

    /// The resource being split into a new game -- shows the new game form
    /// in place of the editor (no navigation).
    @State private var splitting: Splitting?

    private struct Splitting {
        let kind: GameResourceKind
        let id: String
        let description: String
        let url: URL?
    }

    private struct PendingDelete {
        let kind: GameResourceKind
        let id: String
        let description: String
    }

    var body: some View {
        if let game = db.games[gameId], let splitting {
            splitView(splitting, from: game)
        } else if let game = db.games[gameId] {
            DetailForm {
                GameSummarySection(game: game, resource: nil)

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                }

                GameResourcesSections(game: game) { kind, resource in
                    HStack {
                        ResourceSummaryRow(resource: resource)

                        if editableType(for: kind) != nil {
                            Button("Edit", systemImage: "pencil") {
                                path.append(
                                    .resource(
                                        ResourceRoute(
                                            kind: kind, id: resource.id, editing: true,
                                            gameId: game.id)))
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Edit this \(kind.rawValue)")
                        }

                        Button("Move to New Game", systemImage: "arrow.up.forward.square") {
                            let details = [describe(resource), resource.id]
                                .filter { !$0.isEmpty }
                                .joined(separator: " -- ")
                            splitting = Splitting(
                                kind: kind, id: resource.id,
                                description: "\(kind.rawValue): \(details)",
                                url: resource.url)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Create a new game and move this \(kind.rawValue) to it")

                        Button("Delete", systemImage: "trash") {
                            pendingDelete = PendingDelete(
                                kind: kind, id: resource.id,
                                description: describe(resource))
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                        .help("Delete this \(kind.rawValue)")
                    }
                }

                MoveResourceSection(db: $db, gameId: game.id)
                MergeGameSection(db: $db, gameId: game.id)
            }
            .navigationTitle(game.name)
            .confirmationDialog(
                "Delete \(pendingDelete?.kind.rawValue ?? "")?",
                isPresented: Binding {
                    pendingDelete != nil
                } set: {
                    if !$0 { pendingDelete = nil }
                },
                presenting: pendingDelete
            ) { pending in
                Button("Delete", role: .destructive) {
                    delete(pending, from: game)
                }
            } message: { pending in
                Text("\(pending.description)\n\nThis removes it from \(game.name).")
            }
        } else {
            ContentUnavailableView(
                "Not Found", systemImage: "questionmark.folder",
                description: Text("No game with id \(gameId)"))
        }
    }

    /// The new game form for splitting a resource out of `game`, prefilled
    /// from `game` -- Create writes the new game with the resource.
    private func splitView(_ splitting: Splitting, from game: Game) -> some View {
        NewGameView(
            sourceName: splitting.description, sourceURL: splitting.url,
            prefill: "\(game.name) (\(game.manufacturer.rawValue)\(game.year.map { " \($0)" } ?? ""))",
            ipdb: ipdb, db: db
        ) { newGame in
            split(splitting, from: game, into: newGame)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { self.splitting = nil }
                    .help("Back to the game editor without splitting")
            }
        }
    }

    private func split(_ splitting: Splitting, from game: Game, into newGame: Game) {
        log.info("split \(splitting.kind) \(splitting.id) from \(game.id) into new game \(newGame.id)")
        do {
            try db.split(kind: splitting.kind, id: splitting.id, from: game.id, into: newGame)
            error = nil
        } catch {
            log.error("Failed to split \(splitting.kind) \(splitting.id): \(error)")
            self.error = "Unable to move to a new game: \(error.localizedDescription)"
        }
        self.splitting = nil
    }

    private func describe(_ resource: any GameResource) -> String {
        let common = resource.gameResource
        return [
            common.version, common.authors.map(\.name).joined(separator: ", "), common.comment,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " -- ")
    }

    private func delete(_ pending: PendingDelete, from game: Game) {
        log.info("delete \(pending.kind) \(pending.id) from \(game.id)")
        do {
            // the current game -- it may have changed (e.g. a resource edited)
            let current = db.games[game.id] ?? game
            try db.update(current) { game in
                game.remove(kind: pending.kind, id: pending.id)
            }
            error = nil
        } catch {
            log.error("Failed to delete \(pending.kind) \(pending.id): \(error)")
            self.error = "Unable to delete: \(error.localizedDescription)"
        }
    }
}
