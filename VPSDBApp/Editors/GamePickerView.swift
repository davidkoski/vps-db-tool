import SwiftUI
import VPSDB

/// Interstitial for choosing which game a scanned resource belongs to.
///
/// Shows the candidate games (possibly none) and a search field to find
/// others by game.  If `allowsMultiple`, several games can be collected
/// (for pages with material for more than one game).
struct GamePickerView: View {
    let db: Database
    let detail: DetailResult
    let candidates: [String]

    /// Whether multiple games can be chosen -- see
    /// ``EditableGameResource/supportsMultipleGames``.
    var allowsMultiple = false

    /// Called with the chosen game(s).
    let onPick: ([Game]) -> Void

    /// Called to create a new game instead.
    let onNewGame: () -> Void

    @State private var query = ""
    @State private var games = [Game]()
    @State private var selection: Game.ID?
    @State private var sortOrder = [KeyPathComparator(\Game.name, comparator: .localizedStandard)]

    /// Collecting multiple games: clicking a game adds it to `collected`.
    @State private var isCollecting = false
    @State private var collected = [Game]()

    /// Matching games to the files in a folder (e.g. a wheel pack) instead.
    @State private var isMatchingFiles = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(detail.name)
                    .font(.title2)
                    .textSelection(.enabled)
                OpenURLButton(url: detail.url)
            }

            if isMatchingFiles {
                FileMatchView(db: db, onPick: onPick) {
                    isMatchingFiles = false
                }
            } else {
                picker
            }
        }
        .padding()
        .navigationTitle(
            isMatchingFiles ? "Match Files to Games" : isCollecting ? "Choose Games" : "Choose Game"
        )
        .task(id: query) {
            let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else {
                games = candidates.compactMap { db.games[$0] }.sorted(using: sortOrder)
                return
            }
            // debounce: a new query cancels this task (and the sleep) before it searches
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
            games = db.games.all.filter { $0.matches(query) }.sorted(using: sortOrder)
        }
    }

    /// Search + table of games, optionally collecting several.
    @ViewBuilder
    private var picker: some View {
        HStack {
            TextField("Search Games", text: $query)
                .textFieldStyle(.roundedBorder)
            if allowsMultiple && !isCollecting {
                Button("Multiple Games…", systemImage: "square.stack") {
                    isCollecting = true
                }
                .help("This item is for several games -- collect them")
                Button("Match Files…", systemImage: "folder") {
                    isMatchingFiles = true
                }
                .help("Match the files in a folder (e.g. a wheel pack) to games by name")
            }
            Button("New Game…", systemImage: "plus") { onNewGame() }
                .help("None of these -- create a new game")
        }

        if isCollecting {
            collectedGames
        }

        SwiftUI.Table(games, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name, comparator: .localizedStandard)
                .width(min: 150, ideal: 300)
            TableColumn(
                "Manufacturer", value: \.manufacturer.rawValue, comparator: .localizedStandard)
            TableColumn("Year", value: \.sortableYear) { game in
                // avoid locale grouping ("1,995")
                Text(game.year.map(String.init) ?? "")
            }
            .width(min: 40, ideal: 60, max: 80)
        }
        .onChange(of: sortOrder) { _, sortOrder in
            games.sort(using: sortOrder)
        }
        .onChange(of: selection) { _, id in
            guard let id, let game = games.first(where: { $0.id == id }) else { return }
            selection = nil
            if isCollecting {
                if !collected.contains(where: { $0.id == game.id }) {
                    collected.append(game)
                }
            } else {
                onPick([game])
            }
        }
    }

    /// The games collected so far, with accept / cancel.
    private var collectedGames: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                if collected.isEmpty {
                    Text("Click games below (search for others) to add them")
                        .foregroundStyle(.secondary)
                } else {
                    // can be a lot of games (e.g. a wheel pack) -- scroll
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(collected, id: \.id) { game in
                                HStack {
                                    GameRow(game: game)
                                    Button("Remove", systemImage: "xmark.circle.fill") {
                                        collected.removeAll { $0.id == game.id }
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.trailing, 12)  // room for the scroller
                    }
                    // grow with the list (about 24pt a row) up to a limit, then scroll
                    .frame(height: min(CGFloat(collected.count) * 24, 200))
                    .scrollIndicators(.visible)
                }

                HStack {
                    Button("Add All \(games.count) Shown") {
                        for game in games where !collected.contains(where: { $0.id == game.id }) {
                            collected.append(game)
                        }
                    }
                    .disabled(games.isEmpty)
                    .help("Add every game in the list below")

                    if !collected.isEmpty {
                        Button("Clear") { collected = [] }
                    }

                    Spacer()
                    Button("Cancel") {
                        isCollecting = false
                        collected = []
                    }
                    Button("Use ^[\(collected.count) Game](inflect: true)") {
                        onPick(collected)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(collected.isEmpty)
                }
            }
        } label: {
            Text("Games for this item")
        }
    }
}

extension Game {
    /// `year` is optional (not `Comparable`) -- sort unknown years first.
    fileprivate var sortableYear: Int { year ?? 0 }
}
