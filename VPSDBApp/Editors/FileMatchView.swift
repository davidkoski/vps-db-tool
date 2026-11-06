import SwiftUI
import UniformTypeIdentifiers
import VPSDB

/// Choose games for a pack of files (e.g. wheel art or POVs) by matching each
/// file name in a folder to a game -- an alternative to collecting games one
/// at a time in ``GamePickerView``.
///
/// Each file gets a menu of the games matching its name (or none); files
/// without a match, or whose match is removed, get a search field instead.
struct FileMatchView: View {
    let db: Database

    /// Called with the chosen games (one per matched file, without duplicates).
    let onPick: ([Game]) -> Void
    let onCancel: () -> Void

    @State private var folder: URL?
    @State private var files = [FileMatch]()
    @State private var isChoosingFolder = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var showUnmatchedOnly = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Choose Folder…", systemImage: "folder") { isChoosingFolder = true }
                if let folder {
                    Text(folder.path(percentEncoded: false))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folder.path(percentEncoded: false))
                }
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                if !files.isEmpty {
                    Toggle("Unmatched Only", isOn: $showUnmatchedOnly)
                }
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }

            if files.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Files", systemImage: "folder",
                    description: Text("Choose a folder of files named for their games"))
            } else {
                List {
                    ForEach($files) { $file in
                        if !showUnmatchedOnly || file.gameId == nil {
                            FileMatchRow(db: db, file: $file)
                        }
                    }
                }
            }

            HStack {
                Text("\(matchedCount) of \(files.count) files matched")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Use ^[\(chosenGames.count) Game](inflect: true)") {
                    onPick(chosenGames)
                }
                .buttonStyle(.borderedProminent)
                .disabled(chosenGames.isEmpty)
            }
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): load(url)
            case .failure(let error): self.error = error.localizedDescription
            }
        }
        .onAppear {
            if folder == nil {
                isChoosingFolder = true
            }
        }
    }

    private var matchedCount: Int {
        files.count { $0.gameId != nil }
    }

    /// The matched games in file order, each once (several files can match
    /// the same game).
    private var chosenGames: [Game] {
        var seen = Set<String>()
        return files.compactMap { file in
            guard let id = file.gameId, !seen.contains(id), let game = db.games[id] else {
                return nil
            }
            seen.insert(id)
            return game
        }
    }

    /// List the folder's files and match each name to games.
    private func load(_ url: URL) {
        error = nil
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map(\.lastPathComponent)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
            return
        }

        folder = url
        files = []
        isLoading = true
        let db = db
        Task {
            // matchName scans every game -- off the main thread for big packs
            let matched = await Task.detached {
                names.map { FileMatch(fileName: $0, db: db) }
            }.value
            files = matched
            isLoading = false
        }
    }
}

/// A file and the game chosen for it.
private struct FileMatch: Identifiable, Sendable {
    /// The file name.
    let id: String

    /// The game name parsed from the file name.
    let name: String

    /// Games for the menu: the name matches, plus any found by searching.
    var candidates: [Game]

    /// The chosen game, `nil` for none.
    var gameId: String?

    init(fileName: String, db: Database) {
        id = fileName
        name = gameName(fromFileName: fileName)
        candidates = db.matchName(name).sorted()
        // a single match is (very likely) right -- several need a choice
        gameId = candidates.count == 1 ? candidates[0].id : nil
    }
}

private struct FileMatchRow: View {
    let db: Database
    @Binding var file: FileMatch

    /// Searching for a game instead of choosing from the candidates.
    @State private var isSearching = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(file.name)
                Text(file.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(width: 250, alignment: .leading)

            if isSearching || file.candidates.isEmpty {
                VStack(alignment: .leading) {
                    GameSearchField(db: db, initialQuery: file.name) { game in
                        if !file.candidates.contains(where: { $0.id == game.id }) {
                            file.candidates.append(game)
                        }
                        file.gameId = game.id
                        isSearching = false
                    }
                    if !file.candidates.isEmpty {
                        Button("Cancel") { isSearching = false }
                            .buttonStyle(.link)
                    }
                }
            } else {
                Picker("Game", selection: $file.gameId) {
                    Text("None").tag(String?.none)
                    Divider()
                    ForEach(file.candidates, id: \.id) { game in
                        Text(game.label).tag(String?.some(game.id))
                    }
                }
                .labelsHidden()

                Button("Remove Match", systemImage: "xmark.circle.fill") {
                    file.gameId = nil
                    isSearching = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Not this game -- search for another")
            }
        }
        .padding(.vertical, 2)
    }
}

/// A search field with a short list of matching games below -- click one to
/// choose it.
private struct GameSearchField: View {
    let db: Database
    let onSelect: (Game) -> Void

    @State private var query: String
    @State private var results = [Game]()

    /// Max results to show.
    private let limit = 8

    init(db: Database, initialQuery: String, onSelect: @escaping (Game) -> Void) {
        self.db = db
        self.onSelect = onSelect
        self._query = State(initialValue: initialQuery)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Search Games", text: $query)
                .textFieldStyle(.roundedBorder)

            ForEach(results.prefix(limit), id: \.id) { game in
                Button {
                    onSelect(game)
                } label: {
                    GameRow(game: game)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if results.count > limit {
                Text("\(results.count - limit) more…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if results.isEmpty && query.count >= 2 {
                Text("No matching games")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: query) {
            let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard query.count >= 2 else {
                results = []
                return
            }
            // debounce: a new query cancels this task (and the sleep) before it searches
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            results = db.games.all.filter { $0.matches(query) }.sorted()
        }
    }
}

extension Game {
    /// `Name (Manufacturer Year)` for menus.
    fileprivate var label: String {
        if let year {
            "\(name) (\(manufacturer.rawValue) \(year))"
        } else {
            "\(name) (\(manufacturer.rawValue))"
        }
    }
}
