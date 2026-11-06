import Logging
import SwiftUI
import VPSDB

private let log = Logger(label: "GameMerge")

extension EnvironmentValues {
    /// IPDB entries -- set by ``ResourceKindView`` for the views on its stack
    /// (e.g. the new game form when splitting a resource out of a game).
    @Entry var ipdb = IPDB()
}

/// How many search results the merge / move sections show.
private let resultLimit = 50

/// Game editor section: find another game and merge it into this one -- its
/// resources move here and it is deleted (see ``Database/merge(gameId:into:)``).
///
/// Works in place (no navigation): search, then Merge on a result.
struct MergeGameSection: View {
    @Binding var db: Database
    let gameId: String

    @State private var query = ""
    @State private var results = [Game]()
    @State private var pending: Game?
    @State private var error: String?

    var body: some View {
        Section("Merge Another Game Into This One") {
            TextField("Search Games", text: $query)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }

            ForEach(results, id: \.id) { game in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        GameRow(game: game)
                        Text(resourceCounts(game))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Merge…", systemImage: "arrow.triangle.merge") {
                        pending = game
                    }
                    .buttonStyle(.borderless)
                    .help("Move this game's resources here and delete it")
                }
                .help(game.id)
            }
        }
        .task(id: query) {
            await search()
        }
        .confirmationDialog(
            "Merge \(pending?.name ?? "")?",
            isPresented: Binding {
                pending != nil
            } set: {
                if !$0 { pending = nil }
            },
            presenting: pending
        ) { source in
            Button("Merge", role: .destructive) {
                merge(source)
            }
        } message: { source in
            let target = db.games[gameId]?.description ?? gameId
            Text(
                "\(source.description) (\(source.id))\n\(resourceCounts(source))\n\nIts resources move to \(target), then it is deleted."
            )
        }
    }

    private func search() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            results = []
            return
        }
        // debounce: a new query cancels this task (and the sleep) before it searches
        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return
        }
        results = Array(
            db.games.all
                .filter { $0.id != gameId && $0.matches(query) }
                .sorted()
                .prefix(resultLimit))
    }

    private func merge(_ source: Game) {
        log.info("merge game \(source.id) into \(gameId)")
        do {
            try db.merge(gameId: source.id, into: gameId)
            results.removeAll { $0.id == source.id }
            error = nil
        } catch {
            log.error("Failed to merge \(source.id) into \(gameId): \(error)")
            self.error = "Unable to merge: \(error.localizedDescription)"
        }
    }
}

/// Game editor section: find a resource of another game and move it to this
/// one (see ``Database/move(kind:id:from:to:)``).
///
/// Works in place (no navigation): pick a kind, search, then Move on a result.
struct MoveResourceSection: View {
    @Binding var db: Database
    let gameId: String

    /// The kind to search -- `nil` for all kinds.
    @State private var kind: GameResourceKind? = .table
    @State private var query = ""
    @State private var results = [SearchResult]()
    @State private var pending: SearchResult?
    @State private var error: String?

    private static let kinds = GameResourceKind.allCases.sorted().filter { $0 != .game }

    var body: some View {
        Section("Move a Resource Here") {
            HStack {
                Picker("Kind", selection: $kind) {
                    Text("All").tag(GameResourceKind?.none)
                    Divider()
                    ForEach(Self.kinds, id: \.self) { kind in
                        Text(kind.displayName).tag(Optional(kind))
                    }
                }
                .labelsHidden()
                .fixedSize()

                TextField("Search by game, author or URL", text: $query)
                    .textFieldStyle(.roundedBorder)
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }

            ForEach(results, id: \.id) { result in
                if let resource = currentResource(result) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(result.kind.displayName)
                                    .foregroundStyle(.secondary)
                                Text("in \(result.game.description)")
                            }
                            .font(.caption)
                            ResourceSummaryRow(resource: resource)
                        }
                        Button("Move…", systemImage: "arrow.right.circle") {
                            pending = result
                        }
                        .buttonStyle(.borderless)
                        .help("Remove from \(result.game.name) and add to this game")
                    }
                }
            }
        }
        .task(id: SearchKey(kind: kind, query: query)) {
            await search()
        }
        .confirmationDialog(
            "Move \(pending?.kind.rawValue ?? "")?",
            isPresented: Binding {
                pending != nil
            } set: {
                if !$0 { pending = nil }
            },
            presenting: pending
        ) { result in
            Button("Move") {
                move(result)
            }
        } message: { result in
            let description = currentResource(result).map(describe) ?? result.id
            let target = db.games[gameId]?.description ?? gameId
            Text("\(description)\n\nFrom \(result.game.description) to \(target).")
        }
    }

    private struct SearchKey: Equatable {
        let kind: GameResourceKind?
        let query: String
    }

    /// The resource as currently in its game.
    private func currentResource(_ result: SearchResult) -> (any GameResource)? {
        db.games[result.game.id]?[result.kind].first { $0.id == result.id }
    }

    private func search() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            return
        }
        // debounce: a new query cancels this task (and the sleep) before it searches
        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return
        }
        let kinds = kind.map { [$0] } ?? Self.kinds
        results = Array(
            kinds
                .flatMap { db.search(kind: $0, query: query) }
                .filter { $0.kind != .game && $0.game.id != gameId }
                .sorted { $0.game < $1.game }
                .prefix(resultLimit))
    }

    private func move(_ result: SearchResult) {
        log.info("move \(result.kind) \(result.id) from \(result.game.id) to \(gameId)")
        do {
            try db.move(kind: result.kind, id: result.id, from: result.game.id, to: gameId)
            results.removeAll { $0.id == result.id }
            error = nil
        } catch {
            log.error("Failed to move \(result.kind) \(result.id): \(error)")
            self.error = "Unable to move: \(error.localizedDescription)"
        }
    }
}

/// Resource counts by kind, e.g. "2 Tables, 1 Backglasses" -- or "No resources".
private func resourceCounts(_ game: Game) -> String {
    let counts = GameResourceKind.allCases.sorted()
        .filter { $0 != .game }
        .compactMap { kind -> String? in
            let count = game[kind].count
            return count == 0 ? nil : "\(count) \(kind.rawValue)"
        }
    return counts.isEmpty ? "No resources" : counts.joined(separator: ", ")
}

/// Version, authors and comment of a resource on one line.
private func describe(_ resource: any GameResource) -> String {
    let common = resource.gameResource
    return [
        common.version, common.authors.map(\.name).joined(separator: ", "), common.comment,
    ]
    .compactMap { $0 }
    .filter { !$0.isEmpty }
    .joined(separator: " -- ")
}
