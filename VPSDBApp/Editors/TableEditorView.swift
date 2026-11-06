internal import OrderedCollections
import SwiftUI
import VPSDB

/// Create or edit a ``VPSDB/Table`` for a single game.
///
/// Adds the table features and an image picker / cropper for the table
/// image to the common fields -- see ``ResourceEditor``.
struct TableEditorView: View {
    @Binding var db: Database
    /// The source page when creating -- `nil` when editing an existing resource.
    var detail: DetailResult? = nil
    let games: [Game]
    let client: HTTPClient
    var table: VPSDB.Table? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    /// Size of the table image -- portrait 9:16 (as in the web app).
    static let imageSize = CGSize(width: Int(1000 * 9 / 16), height: 1000)

    /// The selected source image + crop for the table image.
    @State private var crop: ImageCrop?

    // A backglass included with the table -- saved along with it, sharing the
    // authors, version, date and urls.
    @State private var includeBackglass = false
    @State private var backglassFeatures = Set<B2SFeature>()
    @State private var backglassComment = ""
    @State private var backglassCrop: ImageCrop?

    @Environment(AppSettings.self) private var settings

    var body: some View {
        ResourceEditor(
            db: $db, detail: detail, games: games, client: client,
            resource: table, onDone: onDone,
            willSave: { table in
                if let crop {
                    let t = Task { [table] in
                        let url = try export(
                            imageDirectory: settings.imagesURL, id: table.id, crop: crop,
                            size: Self.imageSize)
                        return url
                    }
                    let url = try await t.value
                    table.imgUrl = url
                }
            },
            didSave: { table, games in
                if includeBackglass {
                    try await saveBackglass(for: table, games: games)
                }
            }
        ) { table, context in
            Section("Table") {
                TextField("Edition", text: table.edition.orEmpty)

                HStack {
                    Picker("Format", selection: table.tableFormat) {
                        Text("—").tag(TableFormat?.none)
                        ForEach(TableFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(TableFormat?.some(format))
                        }
                    }
                    // the most common format
                    Button("VPX") {
                        table.wrappedValue.tableFormat = .VPX
                    }
                    .disabled(table.wrappedValue.tableFormat == .VPX)
                    .help("Set the format to VPX")
                }
            }

            Section("Parent") {
                LabeledContent("Parent ID") {
                    VStack(alignment: .trailing) {
                        HStack {
                            Button("Root") {
                                table.wrappedValue.isRoot = true
                            }
                            .disabled(table.wrappedValue.isRoot)
                            .help("Mark this table as a root (original) table")

                            TextField("Parent ID", text: table.parentId.orEmpty)
                                .labelsHidden()
                                .onSubmit {
                                    let id = (table.wrappedValue.parentId ?? "")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    updateParent(&table.wrappedValue, parentId: id)
                                }
                        }
                        if let parentId = table.wrappedValue.parentId, !parentId.isEmpty {
                            if table.wrappedValue.isRoot {
                                Text("Root table (no parent)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let parent = db.tables[parentId] {
                                TableSummary(table: parent, game: db[parent])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No table with this id")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                ParentTableSearch(
                    db: db, gameId: table.wrappedValue.gameId, excluding: table.wrappedValue.id
                ) { parent in
                    updateParent(&table.wrappedValue, parentId: parent.id)
                }
            }

            Section("Features") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
                    alignment: .leading
                ) {
                    ForEach(TableFeature.allCases, id: \.self) { feature in
                        Toggle(
                            feature.rawValue,
                            isOn: Binding {
                                table.wrappedValue.hasFeature(feature)
                            } set: { on in
                                table.wrappedValue.setFeature(feature, on)
                            }
                        )
                        .toggleStyle(.checkbox)
                    }
                }
            }

            if let imgUrl = table.wrappedValue.imgUrl {
                CurrentImageSection(url: imgUrl)
            }

            ImageCropPicker(
                title: "Table Image", images: context.images, aspectRatio: Self.imageSize,
                client: client, crop: $crop)

            // a backglass shipped with the table is only added on creation
            if !context.isEditing {
                backglassSection(context: context)
            }
        }
    }

    @ViewBuilder
    private func backglassSection(context: ResourceEditorContext) -> some View {
        Section("Backglass") {
            Toggle("Includes a Backglass", isOn: $includeBackglass)
                .onChange(of: includeBackglass) { _, include in
                    // start from the features mentioned on the page
                    if include && backglassFeatures.isEmpty {
                        backglassFeatures = B2SFeature.scan(context.detail?.text)
                    }
                }

            if includeBackglass {
                Text("Shares the authors, version, date and URLs with the table")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Comment", text: $backglassComment, axis: .vertical)
                    .lineLimit(1 ... 5)

                ForEach(B2SFeature.allCases, id: \.self) { feature in
                    Toggle(
                        feature.rawValue,
                        isOn: Binding {
                            backglassFeatures.contains(feature)
                        } set: { on in
                            if on {
                                backglassFeatures.insert(feature)
                            } else {
                                backglassFeatures.remove(feature)
                            }
                        })
                }
            }
        }

        if includeBackglass {
            ImageCropPicker(
                title: "Backglass Image", images: context.images,
                aspectRatio: B2SEditorView.imageSize, client: client, crop: $backglassCrop)
        }
    }

    /// Save the included backglass for the (just saved) table: the table's
    /// common fields with the backglass's own comment, features and image.
    private func saveBackglass(for table: VPSDB.Table, games: [Game]) async throws {
        var common = table.gameResource
        let comment = backglassComment.trimmingCharacters(in: .whitespacesAndNewlines)
        common.comment = comment.isEmpty ? nil : comment
        
        // just use the first author from the table
        common.authors = common.authors.isEmpty ? [] : [common.authors[0]]

        var b2s = B2S(
            id: newId(),
            features: OrderedSet(B2SFeature.allCases.filter { backglassFeatures.contains($0) }),
            gameResource: common,
            imgUrl: nil)

        if let backglassCrop {
            let t = Task { [b2s] in
                try export(
                    imageDirectory: settings.imagesURL, id: b2s.id, crop: backglassCrop,
                    size: B2SEditorView.imageSize)
            }
            b2s.imgUrl = try await t.value
        }

        // the games as just updated by the table save
        let current = games.map { db.games[$0.id] ?? $0 }
        try ResourceCreation.save(b2s, games: current, db: &db)
    }

    /// Set the parent of `table` -- called when a parent id is entered (return)
    /// or a table is picked from the search.
    private func updateParent(_ table: inout VPSDB.Table, parentId: String) {
        if parentId == "" {
            table.parentId = nil
            return
        }
        if parentId.caseInsensitiveCompare("root") == .orderedSame {
            table.isRoot = true
            return
        }
        guard let parentTable = db.tables.byId[parentId],
            let parentGame = db.games[parentTable.gameId]
        else {
            return
        }
        table.parentId = parentId.isEmpty ? nil : parentId

        if (table.gameResource.comment ?? "").isEmpty {
            let action =
                if parentTable.gameId == table.gameId {
                    "Mod"
                } else {
                    "Retheme"
                }

            let gameDetails =
                if let year = parentGame.year {
                    "\(parentGame.manufacturer.rawValue) \(year)"
                } else {
                    parentGame.manufacturer.rawValue
                }

            let otherAuthorDescription =
                if let author = parentTable.gameResource.authors.first {
                    " by \(author.name)"
                } else {
                    ""
                }

            table.gameResource.comment =
                "\(action) of \(parentGame.name) (\(gameDetails))\(otherAuthorDescription)"
        }

        for author in parentTable.gameResource.authors {
            if !table.gameResource.authors.contains(author) {
                table.gameResource.authors.append(author)
            }
        }

        // a mod / retheme is (almost always) the same format as its parent
        if let format = parentTable.tableFormat {
            table.tableFormat = format
        }

        for feature in parentTable.features {
            if !table.hasFeature(feature) {
                table.features.append(feature)
            }
        }

        if parentTable.gameId == table.gameId {
            table.features.remove(.retheme)
            table.features.append(.mod)
        } else {
            table.features.remove(.mod)
            table.features.append(.retheme)
        }
    }
}

/// One line describing a table: game name, manufacturer, year and authors.
private struct TableSummary: View {
    let table: VPSDB.Table
    let game: Game?

    var body: some View {
        HStack {
            Text(game?.name ?? table.gameName)
            if let game {
                Text(game.manufacturer.rawValue)
                Text(game.year.map(String.init) ?? "")
                    .monospacedDigit()
            }
            Text(table.gameResource.authors.map(\.name).joined(separator: ", "))
                .foregroundStyle(.secondary)
            if let version = table.version {
                Text(version)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}

/// Find a parent table by game name: type a name and pick from the tables of
/// the matching games.
private struct ParentTableSearch: View {
    let db: Database

    /// The game of the table being edited -- for "This Game".
    let gameId: String

    /// The table being edited -- not offered as its own parent.
    let excluding: String

    let onSelect: (VPSDB.Table) -> Void

    @State private var query = ""
    @State private var matches = [VPSDB.Table]()

    /// Showing the tables of this game (rather than search results).
    @State private var isShowingThisGame = false

    /// Max matches to show.
    private let limit = 25

    var body: some View {
        HStack {
            TextField("Find Parent by Game", text: $query)
                .task(id: query) {
                    // the query was cleared to show this game's tables
                    if isShowingThisGame && query.isEmpty {
                        return
                    }
                    isShowingThisGame = false
                    // debounce: a new query cancels this task (and the sleep) before it searches
                    do {
                        try await Task.sleep(for: .milliseconds(100))
                    } catch {
                        return
                    }
                    matches = search(query)
                }

            Button("This Game") {
                isShowingThisGame = true
                query = ""
                matches = thisGameTables
            }
            .disabled(thisGameTables.isEmpty)
            .help("Show the other tables of this game")
        }

        ForEach(matches.prefix(limit), id: \.id) { table in
            Button {
                onSelect(table)
                query = ""
                isShowingThisGame = false
                matches = []
            } label: {
                TableSummary(table: table, game: db[table])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(table.id)
        }
        if matches.count > limit {
            Text("\(matches.count - limit) more…")
                .foregroundStyle(.secondary)
        }
    }

    /// The other tables of this game, oldest first.
    private var thisGameTables: [VPSDB.Table] {
        (db.games[gameId]?.tables ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .filter { $0.id != excluding }
    }

    private func search(_ query: String) -> [VPSDB.Table] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        return db.games.all
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted()
            .flatMap { game in
                game.tables.sorted { $0.createdAt < $1.createdAt }
            }
            .filter { $0.id != excluding }
    }
}

#Preview {
    NavigationStack {
        TableEditorView(
            db: .constant(Database()),
            detail: DetailResult(
                .list,
                url: URL(string: "https://vpuniverse.com/files/file/1234")!,
                kind: .table, name: "Example", author: "Someone", version: "1.0"),
            games: [Game(name: "Example")],
            client: HTTPClient(),
            onDone: { _ in }
        )
    }
}
