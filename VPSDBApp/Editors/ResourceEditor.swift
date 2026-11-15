import Logging
import SwiftUI
import VPSDB

private let log = Logger(label: "ResourceEditor")

/// A ``GameResource`` that can be created from a scanned ``DetailResult`` and
/// edited with ``ResourceEditor``.
protocol EditableGameResource: GameResource {
    static var kind: GameResourceKind { get }

    /// Settable so a resource can be copied to other games with a new id.
    var id: String { get set }

    /// Where these resources live on ``Game``.
    static var gameKeyPath: WritableKeyPath<Game, [Self]> { get }

    /// Build a new resource from a fully scanned detail page.
    init(detail: DetailResult, game: Game, db: Database)

    /// Whether the version field applies (default `true`).
    static var hasVersion: Bool { get }

    /// Whether these are simple enough to create without review in the
    /// editor -- bulk approve on the updates view (default `false`).
    static var supportsBulkApprove: Bool { get }

    /// Whether one page can hold material for several games (e.g. a pack of
    /// wheels or rules) -- the game picker can then choose multiple games and
    /// a copy is saved for each (default `false`).
    static var supportsMultipleGames: Bool { get }
}

extension EditableGameResource {
    static var hasVersion: Bool { true }
    static var supportsBulkApprove: Bool { false }
    static var supportsMultipleGames: Bool { false }
}

/// The resource type for a kind, if it has an editor.
func editableType(for kind: GameResourceKind) -> (any EditableGameResource.Type)? {
    switch kind {
    case .wheelArt: WheelArt.self
    case .table: VPSDB.Table.self
    case .b2s: B2S.self
    case .altColor: AltColors.self
    case .tutorial: Tutorial.self
    case .rule: Rules.self
    case .rom: ROM.self
    case .pupPack: PupPack.self
    case .altSound: AltSound.self
    case .pov: POV.self
    case .topper: Topper.self
    case .mediaPack: MediaPack.self
    case .game, .sound: nil
    }
}

extension WheelArt: EditableGameResource {
    static var kind: GameResourceKind { .wheelArt }
    static var gameKeyPath: WritableKeyPath<Game, [WheelArt]> { \.wheels }
    static var supportsBulkApprove: Bool { true }
    static var supportsMultipleGames: Bool { true }
}

extension VPSDB.Table: EditableGameResource {
    static var kind: GameResourceKind { .table }
    static var gameKeyPath: WritableKeyPath<Game, [VPSDB.Table]> { \.tables }
}

extension B2S: EditableGameResource {
    static var kind: GameResourceKind { .b2s }
    static var gameKeyPath: WritableKeyPath<Game, [B2S]> { \.backglasses }
    static var supportsMultipleGames: Bool { true }
}

extension AltColors: EditableGameResource {
    static var kind: GameResourceKind { .altColor }
    static var gameKeyPath: WritableKeyPath<Game, [AltColors]> { \.altColors }
}

extension Tutorial: EditableGameResource {
    static var kind: GameResourceKind { .tutorial }
    static var gameKeyPath: WritableKeyPath<Game, [Tutorial]> { \.tutorials }
    static var hasVersion: Bool { false }
    static var supportsBulkApprove: Bool { true }
    static var supportsMultipleGames: Bool { true }
}

extension Rules: EditableGameResource {
    static var kind: GameResourceKind { .rule }
    static var gameKeyPath: WritableKeyPath<Game, [Rules]> { \.rules }
    static var supportsBulkApprove: Bool { true }
    static var supportsMultipleGames: Bool { true }
}

extension ROM: EditableGameResource {
    static var kind: GameResourceKind { .rom }
    static var gameKeyPath: WritableKeyPath<Game, [ROM]> { \.roms }
    static var supportsMultipleGames: Bool { true }
}

extension PupPack: EditableGameResource {
    static var kind: GameResourceKind { .pupPack }
    static var gameKeyPath: WritableKeyPath<Game, [PupPack]> { \.pupPacks }
    static var supportsBulkApprove: Bool { true }
}

extension AltSound: EditableGameResource {
    static var kind: GameResourceKind { .altSound }
    static var gameKeyPath: WritableKeyPath<Game, [AltSound]> { \.altSounds }
    static var supportsBulkApprove: Bool { true }
}

extension POV: EditableGameResource {
    static var kind: GameResourceKind { .pov }
    static var gameKeyPath: WritableKeyPath<Game, [POV]> { \.povs }
    // POV packs
    static var supportsMultipleGames: Bool { true }
    static var supportsBulkApprove: Bool { true }
}

extension Topper: EditableGameResource {
    static var kind: GameResourceKind { .topper }
    static var gameKeyPath: WritableKeyPath<Game, [Topper]> { \.toppers }
    static var supportsBulkApprove: Bool { true }
    static var supportsMultipleGames: Bool { true }
}

extension MediaPack: EditableGameResource {
    static var kind: GameResourceKind { .mediaPack }
    static var gameKeyPath: WritableKeyPath<Game, [MediaPack]> { \.mediaPacks }
    static var supportsMultipleGames: Bool { true }
}

/// Information from the source page, for kind-specific fields.
struct ResourceEditorContext {
    /// The fully scanned detail page -- `nil` when editing an existing
    /// resource and its page couldn't be (or hasn't yet been) fetched.
    let detail: DetailResult?

    /// Whether this is editing an existing resource (vs creating a new one).
    let isEditing: Bool

    /// Images from the source page.
    var images: [URL] { detail?.images ?? [] }
}

enum ResourceEditorDisposition: Sendable {
    case ok
    case failed
    case replacedObsolete(URL)
}

/// Shared create / edit / save shell for every resource kind.
///
/// Provides the common ``GameResourceCommon`` fields; `fields` adds the
/// kind-specific ones.  If no `resource` is passed in, one is created from
/// the fetched detail page when the view appears.  If one is passed in, it is
/// edited (and its page is fetched, if possible, for the images / text).
struct ResourceEditor<Resource: EditableGameResource, Fields: View>: View {
    @Binding var db: Database
    let detail: DetailResult?
    /// The game(s) the resource belongs to -- may be a new game, not yet in
    /// the db.  With several games a copy is saved for each.
    let games: [Game]
    let client: HTTPClient

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    /// Kind-specific fields, shown after the common ones.
    @ViewBuilder let fields: (Binding<Resource>, ResourceEditorContext) -> Fields

    /// Called on Save, before the resource is written -- a chance to finish
    /// it (e.g. process an image).  Throwing aborts the save.
    let willSave: (inout Resource) async throws -> Void

    /// Called after the resource is written (with the saved resource and the
    /// games it was saved for) -- e.g. to save a related resource.
    let didSave: (Resource, [Game]) async throws -> Void

    @State private var resource: Resource?

    /// Editing an existing resource (passed in) rather than creating one.
    private let isEditing: Bool

    @State private var isCreating = false
    @State private var isSaving = false

    /// Set after a successful save / merge -- the editor should be dismissed
    /// by `onDone`, but if it isn't, don't allow saving (again) a second time.
    @State private var isFinished = false

    /// The fully scanned detail page (once created).
    @State private var fullDetail: DetailResult?

    /// Description text from the source page, trimmed for display.
    @State private var text: String?

    /// All author names in the db, for completion -- loaded on first use.
    @State private var authorNames: Lazy<[String]>

    init(
        db: Binding<Database>,
        detail: DetailResult?,
        games: [Game],
        client: HTTPClient,
        resource: Resource? = nil,
        onDone: @escaping (ResourceEditorDisposition) -> Void,
        willSave: @escaping (inout Resource) async throws -> Void = { _ in },
        didSave: @escaping (Resource, [Game]) async throws -> Void = { _, _ in },
        @ViewBuilder fields: @escaping (Binding<Resource>, ResourceEditorContext) -> Fields
    ) {
        self._db = db
        self.detail = detail
        precondition(!games.isEmpty)
        self.games = games
        self.client = client
        self._resource = State(initialValue: resource)
        self.isEditing = resource != nil
        precondition(resource != nil || detail != nil, "need a resource or a detail page")
        self._authorNames = State(initialValue: Lazy { db.wrappedValue.authors() })
        self.onDone = onDone
        self.willSave = willSave
        self.didSave = didSave
        self.fields = fields
    }

    var body: some View {
        Group {
            if resource != nil {
                editor
            } else {
                ProgressView("Creating…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(
            currentGames.count == 1 ? primaryGame.name : "\(currentGames.count) Games"
        )
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Save (⌘↩)")
                    .disabled(resource == nil || isSaving || isFinished)
            }
        }
        .task {
            if resource == nil && !isCreating {
                do {
                    try await create()
                } catch {
                    log.error("Failed to create \(Resource.kind): \(error)")
                    finish(.failed)
                }
            } else if isEditing && fullDetail == nil {
                await fetchExistingDetail()
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        // safe: only shown when resource != nil
        let resource = Binding {
            self.resource!
        } set: {
            self.resource = $0
        }
        let common = resource.gameResource
        let context = ResourceEditorContext(detail: fullDetail ?? detail, isEditing: isEditing)

        DetailForm {
            // a merge only makes sense for a single (new) resource
            if !isEditing, !isFinished, currentGames.count == 1 {
                let candidates = primaryGame.shouldMergeURL(resource.wrappedValue)
                if !candidates.isEmpty {
                    MergeSuggestionSection(
                        newVersion: resource.wrappedValue.version,
                        newDate: resource.wrappedValue.createdAt,
                        candidates: candidates
                    ) { other in
                        merge(resource.wrappedValue, into: other)
                    }
                }
            }

            // from a check's fix -- see ChecksView
            ProposedChangesSection()

            if currentGames.count == 1 {
                GameSummarySection(game: primaryGame, resource: resource.wrappedValue)
            } else {
                GameListSection(games: currentGames)
            }

            if let text {
                Text(text)
                    .textSelection(.enabled)
            }

            Section(Resource.kind.displayName) {
                if Resource.hasVersion {
                    TextField("Version", text: common.version.orEmpty)
                        .proposedChange(.version)
                }
                DatePicker("Created", selection: common.createdAt)
                    .proposedChange(.createdAt)
                TextField("Comment", text: common.comment.orEmpty, axis: .vertical)
                    .lineLimit(1 ... 5)
                    .proposedChange(.comment)
            }

            fields(resource, context)

            Section("Authors") {
                TokenField(title: "Author", values: common.authors.names, candidates: authorNames)
                    .proposedChange(.authors)
            }

            EditableList(
                title: "URLs", elements: common.urls.urls,
                newElement: { URL(string: "https://")! }
            ) {
                TextField("URL", value: $0, format: .url)
                    .labelsHidden()
                OpenURLButton(url: $0.wrappedValue)
            }

            ImageThumbnailsSection(urls: context.images)
        }
    }

    /// Fetch the full detail page and build the initial resource from it.
    private func create() async throws {
        guard let detail else { return }
        isCreating = true
        defer { isCreating = false }

        let (resource, fullDetail) = try await ResourceCreation.create(
            Resource.self, detail: detail, game: primaryGame, db: db, client: client)
        self.fullDetail = fullDetail
        self.text = trimText(fullDetail.text)
        self.resource = resource
    }

    /// Editing: fetch the resource's page (best effort) for its images and text.
    private func fetchExistingDetail() async {
        guard let detail else { return }
        do {
            let fullDetail = try await detail.detailRequest.fetch(
                client: client, scanCache: scanCache)
            self.fullDetail = fullDetail
            self.text = trimText(fullDetail.text)
        } catch {
            log.info("Unable to fetch page for \(Resource.kind) \(detail.url): \(error)")
        }
    }

    /// The game as currently in the db (it may have been updated since the
    /// editor opened), or the passed in game if it's new.
    private var currentGames: [Game] {
        games.map { db.games[$0.id] ?? $0 }
    }

    /// The first game -- the resource is created for it, copies for the rest.
    private var primaryGame: Game {
        currentGames[0]
    }

    /// Instead of saving a new resource, add its urls to an existing one
    /// (the same release on another site) and save that.
    private func merge(_ resource: Resource, into other: Resource) {
        guard !isFinished else { return }
        do {
            log.info("merge \(resource.id) into \(other.id)")
            let result = try ResourceCreation.merge(
                resource, into: other, game: primaryGame, db: &db)
            isFinished = true
            log.info("merge done, calling onDone")

            switch result {
            case .none: finish(.failed)
            case .add: finish(.ok)
            case .replace(let url): finish(.replacedObsolete(url))
            }
        } catch {
            log.error("Failed to merge \(Resource.kind): \(error)")
            finish(.failed)
        }
    }

    /// Call `onDone` -- on the next run loop turn, so the caller's navigation
    /// (popping this editor) is a separate update from the db write that was
    /// just made.  Doing both in one update made SwiftUI warn "tried to update
    /// multiple times per frame" and its navigation stacks get out of sync with
    /// their paths (the editor stayed up, back popped the wrong stack).
    private func finish(_ disposition: ResourceEditorDisposition) {
        let onDone = onDone
        DispatchQueue.main.async {
            onDone(disposition)
        }
    }

    private func save() {
        guard var resource, !isSaving, !isFinished else { return }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                if isEditing {
                    resource.gameResource.updatedAt = Date()
                }
                try await willSave(&resource)
                let games = currentGames
                try ResourceCreation.save(resource, games: games, db: &db)
                try await didSave(resource, games)
                isFinished = true
                log.info("save \(resource.id) done, calling onDone")
                finish(.ok)
            } catch {
                log.error("Failed to save \(Resource.kind): \(error)")
                finish(.failed)
            }
        }
    }
}

extension ResourceEditor where Fields == EmptyView {
    /// Editor with only the common fields.
    init(
        db: Binding<Database>,
        detail: DetailResult?,
        games: [Game],
        client: HTTPClient,
        resource: Resource? = nil,
        onDone: @escaping (ResourceEditorDisposition) -> Void
    ) {
        self.init(
            db: db, detail: detail, games: games, client: client, resource: resource,
            onDone: onDone, fields: { _, _ in EmptyView() })
    }
}
