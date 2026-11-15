import SwiftUI
import VPSDB

/// Navigation value identifying a single resource in the database -- shown
/// in its detail view, or its editor if `editing`.
struct ResourceRoute: Hashable {
    let kind: GameResourceKind
    let id: String

    /// Show the editor rather than the detail view.
    var editing = false

    /// The game the resource is in, if known (e.g. from the game editor) --
    /// otherwise the resource's game ref is used, which can be wrong.
    var gameId: String?

    init(kind: GameResourceKind, id: String, editing: Bool = false, gameId: String? = nil) {
        self.kind = kind
        self.id = id
        self.editing = editing
        self.gameId = gameId
    }

    init(_ result: SearchResult) {
        // search results come from the game's own resources
        self.init(
            kind: result.kind, id: result.id,
            gameId: result.kind == .game ? nil : result.game.id)
    }
}

/// Routes a ``ResourceRoute`` to the detail view (or editor) for its kind.
///
/// Edit switches this view to its editor in place -- no navigation -- so the
/// system back button (or Save) pops the whole entry, returning to where it
/// came from (e.g. search).  Editors pushed as routes (`route.editing`, e.g.
/// from the game editor) are plain pushes / pops.
///
/// Navigation here is deliberately plain path pushes and pops:
/// `navigationDestination(isPresented:)`, replacing path elements, and a
/// custom back button with the system one hidden all got SwiftUI's stack out
/// of sync with the path (it ignored later path changes).  It is pushed as a
/// ``KindRoute`` on the kind's single stack -- see there.
struct ResourceDetailView: View {
    @Binding var db: Database
    let route: ResourceRoute

    /// The navigation path this view is on.
    @Binding var path: [KindRoute]

    @Environment(AppSettings.self) private var settings

    /// Client for fetching the resource's page in the editor.
    @State private var client: HTTPClient?

    /// Editing in place (Edit on the detail view).
    @State private var isEditing = false

    var body: some View {
        Group {
            if route.editing || isEditing {
                editor
            } else {
                detail
            }
        }
        .onChange(of: settings.cacheURL, initial: true) { _, cacheURL in
            client = HTTPClient(cache: cacheURL, throttle: .seconds(2))
        }
    }

    private var detail: some View {
        content
            .navigationTitle(route.kind.displayName)
            .toolbar {
                if route.kind == .game || editableType(for: route.kind) != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit", systemImage: "pencil") {
                            isEditing = true
                        }
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Edit (⌘E)")
                        .disabled(
                            route.kind == .game ? db.games[route.id] == nil : editTarget == nil)
                    }
                }
            }
    }

    /// After a save: pop this entry -- the detail view being edited in place
    /// (back to e.g. search), or the pushed editor (back to e.g. the game
    /// editor).
    private func exitEditor() {
        guard path.last?.resourceRoute == route else { return }
        path.removeLast()
    }

    private var editor: some View {
        editorContent
    }

    @ViewBuilder
    private var editorContent: some View {
        // always produce a view -- with none, the modifiers (including the
        // onChange that sets `client`) never run and the view stays blank
        if route.kind == .game {
            GameEditorView(db: $db, gameId: route.id, path: $path)
        } else if let (resource, game) = editTarget, let client {
            KindEditorView(
                db: $db, kind: route.kind, games: [game], client: client,
                resource: resource
            ) { disposition in
                // on failure stay in the editor so the edits aren't lost
                switch disposition {
                case .ok, .replacedObsolete:
                    exitEditor()
                case .failed:
                    break
                }
            }
        } else if editTarget == nil {
            ContentUnavailableView(
                "Not Found", systemImage: "questionmark.folder",
                description: Text("No \(route.kind.rawValue) with id \(route.id)"))
        } else {
            // the client is set on appear
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The resource to edit and the game it belongs to.
    private var editTarget: (any GameResource, Game)? {
        if let gameId = route.gameId {
            // the known game -- look for the resource in it
            guard let game = db.games[gameId],
                let resource = game[route.kind].first(where: { $0.id == route.id })
            else { return nil }
            return (resource, game)
        }
        guard let resource = db.gameResource(kind: route.kind, id: route.id),
            let game = db.games[resource.gameResource.game.id]
        else { return nil }
        return (resource, game)
    }

    @ViewBuilder
    private var content: some View {
        let id = route.id
        switch route.kind {
        case .game:
            found(db.games[id]) { game in
                GameDetailView(game: game) { kind, resourceId in
                    path.append(
                        .resource(ResourceRoute(kind: kind, id: resourceId, gameId: game.id)))
                }
            }
        case .table:
            found(db.tables[id]) { TableDetailView(table: $0) }
        case .b2s:
            found(db.backglasses[id]) { B2SDetailView(b2s: $0) }
        case .tutorial:
            found(db.tutorials[id]) { TutorialDetailView(tutorial: $0) }
        case .rom:
            found(db.roms[id]) { ROMDetailView(rom: $0) }
        case .pupPack:
            found(db.pupPacks[id]) { PupPackDetailView(pupPack: $0) }
        case .altColor:
            found(db.altColors[id]) { AltColorDetailView(altColor: $0) }
        case .altSound:
            found(db.altSounds[id]) { AltSoundDetailView(altSound: $0) }
        case .pov:
            found(db.povs[id]) { POVDetailView(pov: $0) }
        case .wheelArt:
            found(db.wheels[id]) { WheelArtDetailView(wheelArt: $0) }
        case .topper:
            found(db.toppers[id]) { TopperDetailView(topper: $0) }
        case .mediaPack:
            found(db.mediaPacks[id]) { MediaPackDetailView(mediaPack: $0) }
        case .rule:
            found(db.rules[id]) { RuleDetailView(rule: $0) }
        case .sound:
            found(db.sounds[id]) { SoundDetailView(sound: $0) }
        }
    }

    @ViewBuilder
    private func found<T, Content: View>(
        _ value: T?, @ViewBuilder content: (T) -> Content
    ) -> some View {
        if let value {
            content(value)
        } else {
            ContentUnavailableView(
                "Not Found", systemImage: "questionmark.folder",
                description: Text("No \(route.kind.rawValue) with id \(route.id)"))
        }
    }
}

extension Database {
    /// The ``GameResource`` of `kind` with `id` (`nil` for games).
    func gameResource(kind: GameResourceKind, id: String) -> (any GameResource)? {
        switch kind {
        case .game: nil
        case .table: tables[id]
        case .b2s: backglasses[id]
        case .tutorial: tutorials[id]
        case .rom: roms[id]
        case .pupPack: pupPacks[id]
        case .altColor: altColors[id]
        case .altSound: altSounds[id]
        case .pov: povs[id]
        case .wheelArt: wheels[id]
        case .topper: toppers[id]
        case .mediaPack: mediaPacks[id]
        case .rule: rules[id]
        case .sound: sounds[id]
        }
    }
}

// MARK: - Shared pieces

/// Fields common to every ``GameResource``.
struct GameResourceSection: View {
    let resource: any GameResource

    var body: some View {
        let common = resource.gameResource
        Section {
            LabeledContent("Game", value: common.game.name)
            OptionalRow("Version", common.version)
            if !common.authors.isEmpty {
                LabeledContent(
                    "Authors", value: common.authors.map(\.name).joined(separator: ", "))
            }
            OptionalRow("Comment", common.comment)
            DateRows(created: common.createdAt, updated: common.updatedAt)
            LabeledContent("ID", value: resource.id)
                .textSelection(.enabled)
        }
        URLsSection(urls: resource.urls)
    }
}

struct URLsSection: View {
    let urls: [URL]

    var body: some View {
        if !urls.isEmpty {
            Section("URLs") {
                ForEach(urls, id: \.self) { url in
                    Link(url.absoluteString, destination: url)
                }
            }
        }
    }
}

struct DateRows: View {
    let created: Date
    let updated: Date

    var body: some View {
        LabeledContent("Created") { Text(created, format: .dateTime) }
        LabeledContent("Updated") { Text(updated, format: .dateTime) }
    }
}

/// A row that is omitted when the value is `nil` or empty.
struct OptionalRow: View {
    let title: LocalizedStringKey
    let value: String?

    init(_ title: LocalizedStringKey, _ value: String?) {
        self.title = title
        self.value = value
    }

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent(title, value: value)
        }
    }
}

/// Standard container for a detail view.
struct DetailForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
    }
}
