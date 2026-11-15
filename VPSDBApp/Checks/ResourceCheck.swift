import Foundation
import SwiftUI
import VPSDB

/// A check over the resources of some kinds -- finds resources with
/// problems and proposes fixes, which are reviewed in the editor.
///
/// Add new checks to ``allChecks``.
protocol ResourceCheck {
    /// Stable identifier (persisted as the selected check).
    var id: String { get }
    var name: String { get }

    /// The kinds this check applies to.
    var kinds: Set<GameResourceKind> { get }

    /// The problems with `resource` (found in `game`) -- empty if none.
    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String]

    /// Propose an updated resource -- throws if no fix could be found, `nil`
    /// if the item no longer applies (e.g. the resource is gone).  Resolve the
    /// game / resource with `context` -- they may have changed since the check
    /// ran (e.g. another resource of the same game was fixed).
    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal?

    /// Whether selected items can be fixed in bulk, without review (default
    /// `false`) -- see ``FixProposal/apply(_:)``.
    var supportsBulkApply: Bool { get }

    /// Recorded with suppressions -- bump to show suppressed items again
    /// (see ``CheckSuppression``).
    var version: Int { get }
}

extension ResourceCheck {
    var supportsBulkApply: Bool { false }
}

/// All checks, in menu order.
let allChecks: [any ResourceCheck] = [
    MissingFieldsCheck(),
    MissingURLCheck(),
    MissingImagesCheck(),
    DuplicateURLCheck(),
    NoTableFormatCheck(),
    ROMTableCheck(),
    SynchronizeROMSCheck(),
    MissingModCheck(),
]

/// The checks available for `kind`.
func checks(for kind: GameResourceKind) -> [any ResourceCheck] {
    allChecks.filter { $0.kinds.contains(kind) }
}

/// What a fix can use.
struct CheckContext {
    /// The db as of the start of the fix.
    let db: Database
    let settings: AppSettings
    let client: HTTPClient

    /// The game the item's resource was found in.
    func game(for item: CheckItem) -> Game? {
        item.game(in: db)
    }

    /// The item's resource, as currently in its game.
    func resource(for item: CheckItem) -> (any GameResource)? {
        item.resource(in: db)
    }
}

/// A resource found by a check, with the fix for it.
///
/// Holds ids rather than the game / resource -- several items can be on the
/// same game, and fixing one would leave the others with a stale copy.
/// Resolve them with ``FixContext``.
struct CheckItem: Identifiable {
    var id: String { resourceId }

    let check: any ResourceCheck
    let kind: GameResourceKind

    /// The game the resource was found in -- not the resource's `gameId`,
    /// which can be wrong.
    let gameId: String
    let resourceId: String

    let problems: [String]

    // for display / sorting -- as of when the check ran
    let gameName: String
    let version: String
    let authors: String
    let createdAt: Date?

    init(check: any ResourceCheck, game: Game, resource: any GameResource, problems: [String]) {
        self.check = check
        kind = resource.kind
        gameId = game.id
        resourceId = resource.id
        self.problems = problems
        gameName = game.name
        version = resource.version ?? ""
        authors = resource.gameResource.authors.map(\.name).joined(separator: ", ")
        createdAt = resource.createdAt == .distantPast ? nil : resource.createdAt
    }

    /// Propose a fix for this item -- see ``ResourceCheck/fix(_:context:)``.
    func fix(context: CheckContext) async throws -> FixProposal? {
        try await check.fix(self, context: context)
    }

    /// The game the resource was found in, as currently in `db`.
    func game(in db: Database) -> Game? {
        db.games[gameId]
    }

    /// The resource, as currently in its game in `db`.
    func resource(in db: Database) -> (any GameResource)? {
        game(in: db)?[kind].first { $0.id == resourceId }
    }

    /// Whether the check still finds problems with the resource as currently
    /// in `db` -- `false` if it was fixed (or removed) since the check ran.
    func stillApplies(context: CheckContext) -> Bool {
        guard let game = context.game(for: self), let resource = context.resource(for: self) else {
            return false
        }
        return !check.problems(resource, game: game, context: context).isEmpty
    }
}

/// Run `check` over the resources of `kind`.
func run(_ check: any ResourceCheck, kind: GameResourceKind, context: CheckContext) -> [CheckItem] {
    // by game -- the containing game is certain, the resource's gameId may not be
    return context.db.games.all.flatMap { game in
        game[kind].compactMap { resource -> CheckItem? in
            let problems = check.problems(resource, game: game, context: context)
            guard !problems.isEmpty else { return nil }
            return CheckItem(check: check, game: game, resource: resource, problems: problems)
        }
    }
    .sorted { $0.gameName.localizedStandardCompare($1.gameName) == .orderedAscending }
}

/// What a fix proposes: an updated resource to review in the editor (the
/// usual case), or a custom action with its own UI (see ``CustomFix``).
struct FixProposal {
    enum Action {
        /// Review the updated `resource` in its editor.
        ///
        /// - `detail`: the page the update came from -- its images / text are
        ///   shown in the editor
        /// - `changes`: what changed -- highlighted in the editor
        case edit(resource: any GameResource, detail: DetailResult?, changes: [ProposedChange])

        /// A custom UI, free to change any games / resources.
        case custom(CustomFix)
    }

    let action: Action

    /// An updated resource to review in the editor.
    init(resource: any GameResource, detail: DetailResult?, changes: [ProposedChange]) {
        action = .edit(resource: resource, detail: detail, changes: changes)
    }

    private init(action: Action) {
        self.action = action
    }

    /// A custom action -- see ``CustomFix``.
    static func custom(_ fix: CustomFix) -> FixProposal {
        FixProposal(action: .custom(fix))
    }

    /// A custom action with the UI built by `content` -- see ``CustomFix``.
    /// `apply` makes the change without the UI, for bulk apply.
    static func custom<Content: View>(
        title: String,
        apply: ((CustomFixEnvironment) async throws -> Void)? = nil,
        @ViewBuilder content: @escaping (CustomFixEnvironment) -> Content
    ) -> FixProposal {
        .custom(CustomFix(title: title, apply: apply, content: content))
    }

    /// The changes of an edit (none for a custom action).
    var changes: [ProposedChange] {
        if case .edit(_, _, let changes) = action { changes } else { [] }
    }
}

/// A fix with its own UI -- e.g. synchronizing the ROMs of several games.
///
/// Shown in place of the resource editor (pushed on the kind's stack).  The
/// UI changes the db directly -- any number of games and their resources,
/// via ``CustomFixEnvironment/update(_:_:)`` -- and calls
/// ``CustomFixEnvironment/done(fixed:)`` when finished:
///
/// ```swift
/// func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
///     guard let game = context.game(for: item) else { return nil }
///     let others = ...  // games sharing the ROMs, computed from context.db
///     return .custom(title: "Sync ROMs") { env in
///         SyncROMsView(game: game, others: others, env: env)
///     }
/// }
/// ```
struct CustomFix {
    /// Title for the screen.
    let title: String

    /// Builds the UI.
    let content: (CustomFixEnvironment) -> AnyView

    /// Make the change without the UI -- for bulk apply (see
    /// ``ResourceCheck/supportsBulkApply``).  `nil`: needs the UI, so bulk
    /// apply leaves the item for review.  Doesn't call `done`.
    let apply: ((CustomFixEnvironment) async throws -> Void)?

    init<Content: View>(
        title: String,
        apply: ((CustomFixEnvironment) async throws -> Void)? = nil,
        @ViewBuilder content: @escaping (CustomFixEnvironment) -> Content
    ) {
        self.title = title
        self.apply = apply
        self.content = { AnyView(content($0)) }
    }
}

/// The outcome of applying a proposal without review -- see
/// ``FixProposal/apply(_:)``.
enum ApplyResult {
    case applied

    /// Can't be applied automatically -- left for review in the editor / UI.
    case needsReview(String)
}

extension FixProposal {
    /// Apply the proposal without review (bulk apply): save an edit's
    /// resource to the item's game, or run a custom fix's `apply`.
    ///
    /// An edit with no changes (e.g. an image to crop) and a custom fix
    /// without `apply` need review.
    func apply(_ env: CustomFixEnvironment) async throws -> ApplyResult {
        switch action {
        case .edit(let resource, _, let changes):
            guard !changes.isEmpty else {
                return .needsReview("Needs review -- nothing to apply automatically")
            }
            guard let game = env.item.game(in: env.db.wrappedValue) else {
                throw CheckError.noFix("Game not found")
            }
            guard let editable = resource as? any EditableGameResource else {
                return .needsReview("No editor for \(resource.kind.rawValue)")
            }
            try saveEdit(editable, game: game, db: env.db)
            return .applied

        case .custom(let fix):
            guard let apply = fix.apply else {
                return .needsReview("Needs review -- custom fix")
            }
            try await apply(env)
            return .applied
        }
    }
}

/// Save an edited resource to `game`, as the editor's Save does (setting
/// `updatedAt`, and the game ref to `game`).
private func saveEdit<R: EditableGameResource>(_ resource: R, game: Game, db: Binding<Database>)
    throws
{
    var resource = resource
    resource.gameResource.updatedAt = Date()
    // the current game -- it may have changed (e.g. another item applied)
    let current = db.wrappedValue.games[game.id] ?? game
    try ResourceCreation.save(resource, games: [current], db: &db.wrappedValue)
}

/// What a custom fix's UI can use.
struct CustomFixEnvironment {
    /// The item being fixed.
    let item: CheckItem

    /// The live db -- read the current games from it (not a copy taken when
    /// the fix was proposed).
    let db: Binding<Database>

    let settings: AppSettings
    let client: HTTPClient

    /// Finish: back to the checks list.  `fixed`: the change was made -- the
    /// item (and any others no longer having problems) leave the list.
    let done: (_ fixed: Bool) -> Void

    /// Change and write a game (as currently in the db).
    func update(_ gameId: String, _ mutator: (inout Game) -> Void) throws {
        try db.wrappedValue.update(gameId, mutator: mutator)
    }
}

/// A field changed by a fix.
struct ProposedChange: Hashable {
    let field: ResourceField
    let old: String
    let new: String
}

/// Fields of ``GameResourceCommon`` (and kinds) that a fix can change --
/// see ``SwiftUI/View/proposedChange(_:)``.
enum ResourceField: String, Hashable {
    case version = "Version"
    case createdAt = "Created"
    case comment = "Comment"
    case authors = "Authors"
    case urls = "URLs"
    case features = "Features"
}

enum CheckError: LocalizedError {
    case noFix(String)

    var errorDescription: String? {
        switch self {
        case .noFix(let reason): reason
        }
    }
}

// MARK: - Editor highlighting

extension EnvironmentValues {
    /// Changes proposed by a fix -- highlighted by the editor.
    @Entry var proposedChanges: [ProposedChange] = []
}

extension View {
    /// Highlight this row if a fix changed `field`.
    func proposedChange(_ field: ResourceField) -> some View {
        modifier(ProposedChangeModifier(field: field))
    }
}

private struct ProposedChangeModifier: ViewModifier {
    let field: ResourceField

    @Environment(\.proposedChanges) private var changes

    func body(content: Content) -> some View {
        // listRowBackground is ignored for rows in a grouped Form on macOS --
        // tint the field itself
        if changes.contains(where: { $0.field == field }) {
            content
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.proposedChange, in: RoundedRectangle(cornerRadius: 5))
        } else {
            content
        }
    }
}

extension Color {
    /// Background for fields changed by a fix.
    static var proposedChange: Color { .accentColor.opacity(0.18) }
}

/// Lists the changes proposed by a fix, at the top of the editor.
struct ProposedChangesSection: View {
    @Environment(\.proposedChanges) private var changes

    var body: some View {
        if !changes.isEmpty {
            Section {
                ForEach(changes, id: \.self) { change in
                    LabeledContent(change.field.rawValue) {
                        Text("\(change.old) → \(change.new)")
                    }
                }
            } header: {
                Label("Proposed Changes", systemImage: "wand.and.stars")
            } footer: {
                Text("Changed fields are highlighted below -- review and Save")
            }
            .listRowBackground(Color.proposedChange)
        }
    }
}
