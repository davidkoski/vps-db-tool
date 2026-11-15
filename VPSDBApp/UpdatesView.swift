import AppKit
import Logging
import SwiftUI
import UniformTypeIdentifiers
import VPSDB

private let log = Logger(label: "UpdatesView")

/// Updates for a single kind: scans the sites for new / changed resources.
struct UpdatesView: View {
    /// Holds the suppressed updates.
    let document: VPSDBDocument

    @Binding var db: Database
    let ipdb: IPDB
    let kind: GameResourceKind

    /// Whether this kind's tab is selected -- a running scan is cancelled
    /// when the user switches to another kind.
    var isActive = true

    /// The site to fetch from (``Site`` raw value), or `""` for all sites --
    /// per kind, as the sites with list pages differ by kind.
    @AppStorage private var fetchSite: String

    /// The kind's navigation path -- the fix screens are pushed onto it.
    @Binding var path: [KindRoute]

    /// The toolbar search text -- shows only items whose columns contain it.
    let query: String

    init(
        document: VPSDBDocument, db: Binding<Database>, ipdb: IPDB, kind: GameResourceKind,
        isActive: Bool = true, query: String = "", path: Binding<[KindRoute]>
    ) {
        self.document = document
        self._db = db
        self.ipdb = ipdb
        self.kind = kind
        self.isActive = isActive
        self.query = query
        self._path = path
        self._fetchSite = AppStorage(wrappedValue: "", "fetchSite.\(kind.rawValue)")
    }

    @Environment(AppSettings.self) private var settings

    /// Client for the site scans (throttled).
    @State private var client: HTTPClient?

    /// Separate client for detail pages (editors, paste) so they aren't
    /// queued behind a running scan by the throttle.
    @State private var detailClient: HTTPClient?
    @State private var items = [UpdateItem]()
    @State private var isFetching = false
    /// The running scan -- cancelled when this view is removed for good
    /// (not when an editor is pushed on top of it).
    @State private var scanLifetime = TaskLifetime()
    @State private var sortOrder = [
        KeyPathComparator(\UpdateItem.detail.resolvedDate, order: .reverse)
    ]

    /// Push a fix screen.  Fixes start at this view (the stack's root) and
    /// push picker -> (new game) -> editor; ``finishFix()`` pops them all.
    private func show(_ route: FixRoute) {
        navLog.info("NAV [\(kind)] updates show \(route.tag), path \(path.map(\.debugName))")
        path.append(.view(route.tag) { self.destination(route) })
    }

    /// Start fixing an item (from the list, the stack's root) -- the path
    /// should be empty; if it isn't, its entries are stale (not on screen: a
    /// pop that didn't update the path) and are dropped rather than pushed onto.
    private func start(_ route: FixRoute) {
        guard !path.isEmpty else {
            show(route)
            return
        }
        log.warning("stale navigation path \(path.map(\.debugName)) -- resetting")
        navLog.info(
            "NAV [\(kind)] updates start \(route.tag) with stale path \(path.map(\.debugName))")
        path = [.view(route.tag) { self.destination(route) }]
    }

    /// Done fixing an item -- back to the list.
    private func finishFix() {
        navLog.info("NAV [\(kind)] updates finishFix, path \(path.map(\.debugName))")
        path.removeAll()
        navLog.info("NAV [\(kind)] updates finishFix after, path \(path.map(\.debugName))")
    }

    /// Back to the game picker -- popping to it if it is on the path, else
    /// pushing one (never replacing the editor: plain pushes / pops only).
    private func changeGame(_ target: EditTarget) {
        if let index = path.lastIndex(where: { $0.tag == FixRoute.pickGameTag }) {
            path.removeLast(path.count - 1 - index)
        } else {
            show(.pickGame(target.item, target.client, target.kind))
        }
    }

    @State private var selection = Set<UpdateItem.ID>()

    /// Notes from bulk approve on items left in the list (needs review / errors).
    @State private var notes = [UpdateItem.ID: ItemNote]()

    /// The running bulk approve -- cancelled like the scan.
    @State private var approveLifetime = TaskLifetime()
    @State private var approveProgress: ApproveProgress?

    /// Bump to move keyboard focus to the table.
    @State private var focusRequest = 0

    /// Fetches of pasted URLs in progress.
    @State private var pasteCount = 0
    @State private var message: String?

    /// Number of list pages to fetch -- shared by every kind's tab.
    @AppStorage("fetchPages") private var pages = 1

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if canFetch {
                    Button("Fetch", systemImage: "arrow.down.circle") { fetch() }
                        .disabled(isFetching || client == nil)
                    if availableSites.count > 1 {
                        Picker("Sites", selection: $fetchSite) {
                            Text("All Sites").tag("")
                            Divider()
                            ForEach(availableSites, id: \.self) { site in
                                Text(site.rawValue).tag(site.rawValue)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .disabled(isFetching)
                        .help("The site(s) to fetch from")
                    }
                    Stepper(value: $pages, in: 1 ... 250) {
                        Text("^[\(pages) page](inflect: true)")
                            .monospacedDigit()
                    }
                    .fixedSize()
                    .disabled(isFetching)
                }
                Button("Add from Clipboard", systemImage: "plus") { pasteURLs() }
                    .help("Add update items from the URL(s) on the clipboard (or ⌘V in the table)")
                    .disabled(detailClient == nil)
                if pasteCount > 0 {
                    ProgressView()
                        .controlSize(.small)
                }
                if isFetching {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel") { scanLifetime.cancel() }
                }
                Spacer()

                if let approveProgress {
                    ProgressView(
                        value: Double(approveProgress.done), total: Double(approveProgress.total)
                    ) {
                        Text("Approving \(approveProgress.done + 1) of \(approveProgress.total)…")
                    }
                    .frame(width: 200)
                    Button("Cancel") { approveLifetime.cancel() }
                } else if supportsBulkApprove {
                    let eligible = bulkTargets(selection)
                    Button("Approve Selected (\(eligible.count))", systemImage: "checkmark.circle")
                    {
                        approve(selection)
                    }
                    .disabled(eligible.isEmpty || detailClient == nil)
                    .help(approveHelp(selection))
                }

                Menu("Suppress", systemImage: "eye.slash") {
                    suppressMenuItems(selection)
                }
                .fixedSize()
                .disabled(selection.isEmpty || approveProgress != nil)
                .help("Don't offer the selected updates (stored in the document)")

                Button("Remove", systemImage: "trash") { remove(selection) }
                    .disabled(selection.isEmpty || approveProgress != nil)
                    .help("Remove the selected items from the list (⌫)")

                let shown = visibleItems.count
                Text(
                    shown == items.count
                        ? "\(items.count) items" : "\(shown) of \(items.count) items"
                )
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            SwiftUI.Table(visibleItems, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.detail.name, comparator: .localizedStandard) { item in
                    Text("\(item.detail.name)")
                }
                .width(min: 150, ideal: 300)
                TableColumn("Game", value: \.gameLabel, comparator: .localizedStandard) { item in
                    HStack(spacing: 4) {
                        switch item.gameMatch {
                        case .exact:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .help("The name matches the game")
                        case .fuzzy:
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.orange)
                                .help("Fuzzy name match -- check the game")
                        case .unmatched:
                            EmptyView()
                        }
                        Text(item.gameLabel)
                            .foregroundStyle(item.gameIds.count == 1 ? .primary : .secondary)
                    }
                }
                .width(min: 120, ideal: 250)
                TableColumn("Author", value: \.detail.author, comparator: .localizedStandard)
                TableColumn("Issue", value: \.issue, comparator: .localizedStandard) { item in
                    HStack(spacing: 4) {
                        Text(item.issue)
                        if let note = notes[item.id] {
                            Label(note.message, systemImage: note.isError ? "xmark.octagon" : "eye")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(note.isError ? .red : .orange)
                                .help(note.message)
                        }
                    }
                }
                TableColumn("Date", value: \.detail.resolvedDate) { item in
                    Text(item.detail.resolvedDate, format: .dateTime.year().month().day())
                }
                .width(min: 70, ideal: 80, max: 100)
                TableColumn("Site", value: \.detail.site.rawValue) { item in
                    Link(item.detail.site.rawValue, destination: item.detail.url)
                        .help(item.detail.url.absoluteString)
                }
                .width(min: 40, ideal: 50, max: 70)
            }
            // focuses on (re)attach to the window and whenever focusRequest changes
            .tableFocus(trigger: focusRequest)
            .contextMenu(forSelectionType: UpdateItem.ID.self) { ids in
                if ids.count == 1, let item = item(ids) {
                    Button("Fix") { fix(item) }
                    if item.fix == .missing {
                        Button("Fix with Game…") { chooseGame(item) }
                    }
                    editExistingMenuItems(item)
                    Link("Open in Browser", destination: item.detail.url)
                    Divider()
                    Menu("Suppress") { suppressMenuItems(ids) }
                    Button("Remove") { remove(ids) }
                } else if ids.count > 1 {
                    if supportsBulkApprove {
                        Button("Approve \(bulkTargets(ids).count) Selected") { approve(ids) }
                            .disabled(bulkTargets(ids).isEmpty || approveProgress != nil)
                    }
                    Menu("Suppress \(ids.count) Items") { suppressMenuItems(ids) }
                    Button("Remove \(ids.count) Items") { remove(ids) }
                }
            } primaryAction: { ids in
                // Return or double-click -- only for a single item (never bulk)
                if ids.count == 1, let item = item(ids) {
                    fix(item)
                }
            }
            .onDeleteCommand {
                remove(selection)
            }
            .onChange(of: sortOrder) { _, sortOrder in
                items.sort(using: sortOrder)
            }
            .onPasteCommand(of: [.url, .plainText]) { _ in
                // read the pasteboard directly -- simpler than the item providers
                pasteURLs()
            }
        }
        .alert(
            "Add from Clipboard",
            isPresented: Binding {
                message != nil
            } set: { _ in
                message = nil
            }
        ) {
            Button("OK") {}
        } message: {
            Text(message ?? "")
        }
        .onChange(of: isActive) { _, isActive in
            if !isActive {
                scanLifetime.cancel()
            }
        }
        .onChange(of: settings.cacheURL, initial: true) { _, cacheURL in
            client = HTTPClient(cache: cacheURL, throttle: .seconds(2))
            detailClient = HTTPClient(cache: cacheURL, throttle: .seconds(2))
        }
        .onAppear {
            // also runs when popping back from the picker / editor
            focusRequest += 1
        }
        .onChange(of: query) {
            // actions apply to the selection -- keep it to the rows shown
            selection.formIntersection(visibleItems.map(\.id))
        }
        .onChange(of: path.isEmpty) { _, isEmpty in
            if isEmpty {
                focusRequest += 1
            }
        }
    }

    /// The items matching the search text (in the columns' text).
    private var visibleItems: [UpdateItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return items }
        return items.filter { item in
            matchesQuery(
                query,
                [
                    item.detail.name, item.gameLabel, item.detail.author, item.issue,
                    item.detail.resolvedDate.formatted(.dateTime.year().month().day()),
                    item.detail.site.rawValue, notes[item.id]?.message,
                ])
        }
    }

    /// The screen for a fix route -- pushed by ``show(_:)``.
    @ViewBuilder
    private func destination(_ route: FixRoute) -> some View {
        switch route {
        case .pickGame(let item, let client, let kind):
            GamePickerView(
                db: db, detail: item.detail, candidates: item.gameIds.sorted(),
                allowsMultiple: editableType(for: kind)?.supportsMultipleGames ?? false
            ) { games in
                show(.edit(EditTarget(item: item, games: games, client: client, kind: kind)))
            } onNewGame: {
                show(.newGame(item, client, kind))
            }
        case .newGame(let item, let client, let kind):
            NewGameView(detail: item.detail, ipdb: ipdb, db: db) { game in
                // not in the db yet -- saved along with the resource
                show(.edit(EditTarget(item: item, games: [game], client: client, kind: kind)))
            }
        case .editExisting(let item, let client, let resourceId):
            existingEditor(item: item, client: client, resourceId: resourceId)
        case .edit(let target):
            editor(target)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Change Game", systemImage: "arrow.triangle.swap") {
                            // discards edits -- the editor is recreated for the new game
                            changeGame(target)
                        }
                        .help("Choose a different game")
                    }
                    let alternates = alternateKinds(target.kind)
                    if !alternates.isEmpty {
                        ToolbarItem(placement: .primaryAction) {
                            Menu("Edit As", systemImage: "arrow.left.arrow.right") {
                                ForEach(alternates, id: \.self) { kind in
                                    Button(kind.displayName) {
                                        // recreated as the new kind (pushed --
                                        // back returns to this editor)
                                        show(.edit(target.with(kind: kind)))
                                    }
                                }
                            }
                            .help("Re-create as a different kind (miscategorized on the site)")
                        }
                    }
                }
        }
    }

    /// "Edit Existing" for a version update: open the editor on the existing
    /// resource (with the page's images / text) instead of updating the
    /// version automatically.  One item per existing resource if several.
    @ViewBuilder
    private func editExistingMenuItems(_ item: UpdateItem) -> some View {
        if case .version(let fileIds, _, _) = item.fix, hasEditor(kind), let client = detailClient {
            let resources = fileIds.sorted().compactMap { db.gameResource(kind: kind, id: $0) }
            if resources.count == 1 {
                Button("Edit Existing…") {
                    start(.editExisting(item, client, resourceId: resources[0].id))
                }
            } else if resources.count > 1 {
                Menu("Edit Existing") {
                    ForEach(resources, id: \.id) { resource in
                        Button(
                            "\(resource.gameResource.game.name) \(resource.version ?? "")"
                        ) {
                            start(.editExisting(item, client, resourceId: resource.id))
                        }
                    }
                }
            }
        }
    }

    /// Editor for an existing resource, from a version update.
    @ViewBuilder
    private func existingEditor(item: UpdateItem, client: HTTPClient, resourceId: String)
        -> some View
    {
        if let resource = db.gameResource(kind: kind, id: resourceId),
            let game = db.games[resource.gameResource.game.id]
        {
            KindEditorView(
                db: $db, kind: kind, detail: item.detail, games: [game], client: client,
                resource: resource
            ) { disposition in
                switch disposition {
                case .ok, .replacedObsolete:
                    items = items.filter { $0 != item }
                    finishFix()
                case .failed:
                    // stay in the editor so the edits aren't lost
                    break
                }
            }
        } else {
            ContentUnavailableView(
                "Not Found", systemImage: "questionmark.folder",
                description: Text("No \(kind.rawValue) with id \(resourceId)"))
        }
    }

    /// Editor view per kind for creating a missing resource.
    @ViewBuilder
    private func editor(_ target: EditTarget) -> some View {
        let onDone = { (disposition: ResourceEditorDisposition) in
            let success =
                switch disposition {
                case .ok, .replacedObsolete: true
                case .failed: false
                }

            switch disposition {
            case .replacedObsolete(let url):
                document.model.suppressedURLs[url] = .obsolete
            default:
                break
            }

            if success {
                items = items.filter { $0 != target.item }
            }

            finishFix()
        }

        KindEditorView(
            db: $db, kind: target.kind, detail: target.detail, games: target.games,
            client: target.client, onDone: onDone)
    }

    /// Kinds an item can be re-created as -- e.g. many "media packs" on the
    /// sites are really PuP packs, wheels, toppers or rules.
    private func alternateKinds(_ kind: GameResourceKind) -> [GameResourceKind] {
        switch kind {
        case .table:
            return [.pupPack]
        default:
            let interchangeable: [GameResourceKind] = [
                .mediaPack, .pupPack, .wheelArt, .topper, .rule,
            ]
            guard interchangeable.contains(kind) else { return [] }
            return interchangeable.filter { $0 != kind }
        }
    }

    private func item(_ ids: Set<UpdateItem.ID>) -> UpdateItem? {
        guard let id = ids.first else { return nil }
        return items.first { $0.id == id }
    }

    private func hasEditor(_ kind: GameResourceKind) -> Bool {
        switch kind {
        case .wheelArt, .rule, .rom, .pupPack, .altSound, .pov, .topper, .mediaPack, .tutorial,
            .b2s, .table, .altColor:
            true
        default: false
        }
    }

    /// Fix a missing item, always going through the game picker
    /// (e.g. when the name matched the wrong game).
    private func chooseGame(_ item: UpdateItem) {
        guard hasEditor(kind), let client = detailClient else { return }
        start(.pickGame(item, client, kind))
    }

    private func fix(_ item: UpdateItem) {
        log.info("fix \(item.detail.name): \(item.issue) \(item.detail.url)")

        switch item.fix {
        case .missing, .mergeURL, .replaceURL, .mergeMultiple:
            guard hasEditor(kind), let client = detailClient else { break }
            if item.gameIds.count == 1, let gameId = item.gameIds.first,
                let game = db.games[gameId]
            {
                start(.edit(EditTarget(item: item, games: [game], client: client, kind: kind)))
            } else {
                // zero or multiple matches -- let the user choose
                start(.pickGame(item, client, kind))
            }
        case .version(let fileIds, _, let newVersion):
            guard let client = detailClient else { break }
            Task {
                var fixed = false
                let now = Date()

                let updated: Date
                switch item.detail.date {
                case .unknown, .undated:
                    do {
                        isFetching = true
                        defer { isFetching = false }
                        let detail = try await item.detail.detailRequest.fetch(
                            client: client, scanCache: scanCache)
                        updated = detail.resolvedDate
                    } catch {
                        log.error("Unable to fetch \(item.detail.url): \(error)")
                        return
                    }
                case .date(let date):
                    updated = date
                }

                func update<T: GameResource>(_ item: T) -> T {
                    if fileIds.contains(item.id) {
                        var new = item
                        new.gameResource.version = newVersion
                        new.gameResource.createdAt = updated
                        new.gameResource.updatedAt = now
                        return new
                    } else {
                        return item
                    }
                }

                for gameId in item.gameIds {
                    switch kind {
                    case .table:
                        try! db.update(gameId) { game in
                            game.tables = game.tables.map(update)
                        }
                        fixed = true
                    case .b2s:
                        try! db.update(gameId) { game in
                            game.backglasses = game.backglasses.map(update)
                        }
                        fixed = true
                    case .wheelArt:
                        try! db.update(gameId) { game in
                            game.wheels = game.wheels.map(update)
                        }
                        fixed = true
                    case .topper:
                        try! db.update(gameId) { game in
                            game.toppers = game.toppers.map(update)
                        }
                        fixed = true

                    default:
                        break
                    }
                }

                if fixed {
                    items = items.filter { $0 != item }
                }
            }

        }
    }

    // MARK: - Suppress

    private enum SuppressAction {
        case permanent
        case obsolete
        case week
        case month
        case version
        case missingGame
    }

    @ViewBuilder
    private func suppressMenuItems(_ ids: Set<UpdateItem.ID>) -> some View {
        Button("Never Show Again") { suppress(ids, .permanent) }
            .help("Not a resource -- never offer this url")
        Button("Obsolete") { suppress(ids, .obsolete) }
            .help("Not a resource -- never offer this url")
        Divider()
        Button("Hide for 1 Week") { suppress(ids, .week) }
        Button("Hide for 1 Month") { suppress(ids, .month) }
        Divider()
        Button("Bad Version") { suppress(ids, .version) }
            .disabled(!items.contains { ids.contains($0.id) && $0.detail.version != nil })
            .help("Hide while the parsed version stays the same")
        Button("Game Not in Database") { suppress(ids, .missingGame) }
            .help("The game isn't in the database (any matched games are wrong)")
    }

    /// Record the suppression in the document and take the items off the list.
    private func suppress(_ ids: Set<UpdateItem.ID>, _ action: SuppressAction) {
        var suppressed = Set<UpdateItem.ID>()

        for item in items where ids.contains(item.id) {
            let reason: SuppressionReason
            switch action {
            case .permanent:
                reason = .permanent
            case .obsolete:
                reason = .obsolete
            case .week:
                reason = .temporary(for: DateComponents(day: 7))
            case .month:
                reason = .temporary(for: DateComponents(month: 1))
            case .version:
                // only items with a version
                guard let version = item.detail.version else { continue }
                reason = .version(parsed: version)
            case .missingGame:
                reason = .missingGame(
                    name: ParsedGameName(item.detail.name).name,
                    falsePositives: item.gameIds)
            }

            log.info("suppress \(item.detail.url): \(reason)")
            document.model.suppressedURLs[item.detail.url] = reason
            suppressed.insert(item.id)
        }

        remove(suppressed)
    }

    // MARK: - Remove / bulk approve

    /// Discard items from the list (they come back on the next fetch).
    private func remove(_ ids: Set<UpdateItem.ID>) {
        items.removeAll { ids.contains($0.id) }
        for id in ids {
            notes[id] = nil
        }
        selection.subtract(ids)
    }

    private var supportsBulkApprove: Bool {
        editableType(for: kind)?.supportsBulkApprove ?? false
    }

    /// The items (and their games) that can be approved without the editor:
    /// missing, with exactly one matching game.
    private func bulkTargets(_ ids: Set<UpdateItem.ID>) -> [(item: UpdateItem, game: Game)] {
        guard supportsBulkApprove else { return [] }
        return
            items
            .filter { ids.contains($0.id) && $0.fix == .missing && $0.gameIds.count == 1 }
            .compactMap { item in
                item.gameIds.first.flatMap { db.games[$0] }.map { (item, $0) }
            }
    }

    private func approveHelp(_ ids: Set<UpdateItem.ID>) -> String {
        let skipped = ids.count - bulkTargets(ids).count
        var help = "Create the selected items without the editor"
        if skipped > 0 {
            help += " -- \(skipped) skipped (not missing, or not exactly one game)"
        }
        return help
    }

    /// Create + save the eligible items, one at a time.  Saved items are removed;
    /// anything that needs review (e.g. would merge into an existing item) or
    /// fails stays in the list with a note.
    private func approve(_ ids: Set<UpdateItem.ID>) {
        guard let client = detailClient, let type = editableType(for: kind), approveProgress == nil
        else {
            return
        }
        let targets = bulkTargets(ids)
        guard !targets.isEmpty else { return }

        approveProgress = ApproveProgress(done: 0, total: targets.count)

        approveLifetime.task = Task {
            defer {
                approveProgress = nil
                // leave what's left of the targets selected, to look at
                let remaining = Set(targets.map(\.item.id)).intersection(items.map(\.id))
                selection = remaining
                focusRequest += 1
            }

            for (item, game) in targets {
                if Task.isCancelled { break }
                do {
                    switch try await approve(type, item: item, game: game, client: client) {
                    case .saved:
                        items.removeAll { $0.id == item.id }
                        notes[item.id] = nil
                    case .needsReview(let reason):
                        notes[item.id] = ItemNote(message: reason, isError: false)
                    }
                } catch is CancellationError {
                    break
                } catch {
                    log.error("approve \(item.detail.url) failed: \(error)")
                    notes[item.id] = ItemNote(message: "\(error)", isError: true)
                }
                approveProgress?.done += 1
            }
        }
    }

    private enum ApproveResult {
        case saved
        case needsReview(String)
    }

    private func approve<Resource: EditableGameResource>(
        _ type: Resource.Type, item: UpdateItem, game: Game, client: HTTPClient
    ) async throws -> ApproveResult {
        // the db may have changed since the item was listed (e.g. another approve)
        if db.existing(url: item.detail.url, kind: Resource.kind) != nil {
            return .needsReview("Already in the database")
        }

        let (resource, _) = try await ResourceCreation.create(
            Resource.self, detail: item.detail, game: game, db: db, client: client)

        let current = db.games[game.id] ?? game
        if !current.shouldMergeURL(resource).isEmpty {
            // only adds a url to an existing item -- look at it in the editor
            return .needsReview(
                "Looks like an existing item from another site -- review in the editor")
        }

        try ResourceCreation.save(resource, game: current, db: &db)
        return .saved
    }

    /// Sites with list pages to scan for this kind.
    private var availableSites: [Site] {
        Site.scanSites.filter { !($0.scanner?.sources(kind: kind).isEmpty ?? true) }
    }

    /// Whether any site has list pages to scan for this kind (tutorials don't).
    private var canFetch: Bool {
        !availableSites.isEmpty
    }

    /// The sites a fetch scans: the selected one, or all of them (also if the
    /// stored selection doesn't apply to this kind).
    private var fetchSites: [Site] {
        if let site = Site(rawValue: fetchSite), availableSites.contains(site) {
            [site]
        } else {
            availableSites
        }
    }

    /// Create update items from URLs on the clipboard: fetch + scan each page
    /// (any site -- YouTube, VPU, generic pages) and match it against the db.
    private func pasteURLs() {
        guard let client = detailClient else { return }

        let urls = clipboardURLs()
        guard !urls.isEmpty else {
            message = "No URLs on the clipboard."
            return
        }

        var alreadyPresent = [URL]()

        for url in urls {
            // skip anything already in the db -- no need to fetch it
            if db.existing(url: url, kind: kind) != nil {
                alreadyPresent.append(url)
                continue
            }

            pasteCount += 1
            Task {
                defer { pasteCount -= 1 }
                do {
                    let request = DetailScanRequest(url, kind)
                    let detail = try await request.fetch(client: client, scanCache: scanCache)
                    let item = missingItem(db: db, detail: detail)
                    if let listed = items.first(where: { $0.detail.url == detail.url }) {
                        selection = [listed.id]
                    } else {
                        items.insert(item, at: 0)
                        selection = [item.id]
                    }
                    focusRequest += 1
                } catch {
                    log.error("paste \(url) failed: \(error)")
                    message = "Unable to read \(url):\n\(error)"
                }
            }
        }

        if !alreadyPresent.isEmpty {
            message =
                "Already in the database:\n"
                + alreadyPresent.map(\.absoluteString).joined(separator: "\n")
        }
    }

    private func clipboardURLs() -> [URL] {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
            !urls.isEmpty
        {
            return urls.filter { $0.scheme?.hasPrefix("http") == true }
        }
        let text = pasteboard.string(forType: .string) ?? ""
        return
            text
            .split(whereSeparator: \.isWhitespace)
            .compactMap { URL(string: String($0)) }
            .filter { $0.scheme?.hasPrefix("http") == true && $0.host() != nil }
    }

    /// Whether `lhs` sorts before `rhs` with the table's current sort order.
    private func sortsBefore(_ lhs: UpdateItem, _ rhs: UpdateItem) -> Bool {
        for comparator in sortOrder {
            switch comparator.compare(lhs, rhs) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: continue
            }
        }
        return false
    }

    private func fetch() {
        guard let client, !isFetching else { return }
        isFetching = true
        items = []
        notes = [:]

        // keeps running while an editor is pushed on top; cancelled by the
        // Cancel button or when this view goes away (see TaskLifetime)
        scanLifetime.task = Task {
            defer { isFetching = false }

            for await item in scan(
                db: db, client: client, kind: kind, sites: fetchSites, pages: max(pages, 1),
                suppress: document.model.suppressedURLs
            ) {
                // keep the current sort order as items arrive
                let index = items.firstIndex { sortsBefore(item, $0) }
                items.insert(item, at: index ?? items.endIndex)
            }
        }
    }
}

#Preview {
    UpdatesView(
        document: VPSDBDocument(), db: .constant(Database()), ipdb: IPDB(), kind: .table,
        path: .constant([])
    )
    .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}

private func scan(
    db: Database,
    client: HTTPClient,
    kind: GameResourceKind,
    sites: [Site],
    pages: Int,
    suppress: [URL: SuppressionReason]
) -> some AsyncSequence<UpdateItem, Never> {

    let hasVersion =
        switch kind {
        case .table, .b2s, .wheelArt, .topper: true
        default: false
        }

    @Sendable
    func match(_ item: DetailResult) -> [any Metadata]? {
        db.existing(url: item.url, kind: kind)
    }

    @Sendable
    func followItem(_ item: DetailResult) -> Bool {
        // if the item is in the database and we don't have a version value
        // then we follow the link to check the version
        guard hasVersion else { return false }

        if item.version != nil {
            // we have the version, don't need to follow
            return false
        }

        if let match = match(item), !match.isEmpty {
            return true
        }

        return false
    }

    let maxAge = pages > 1 ? Duration.seconds(2 * 24 * 3600) : .seconds(12 * 3600)

    return AsyncStream { continuation in
        let producer = Task {
            await withTaskGroup { group in
                for site in sites {
                    let requests = ListScanRequest.pages(Array(1 ... pages), site: site, kind)
                    group.addTask {
                        let stream = gather(
                            client: client,
                            maxAge: maxAge,
                            scanCache: scanCache,
                            requests: requests,
                            suppress: suppress,
                            follow: followItem(_:))

                        for await item in stream {
                            continuation.yield(item)
                        }
                    }
                }
            }
            // all sites done -- end the sequence (otherwise `for await` never returns)
            continuation.finish()
        }

        continuation.onTermination = { _ in
            producer.cancel()
        }
    }
    .filter {
        if let reason = suppress[$0.url] {
            return !reason.shouldSuppress(detail: $0, db: db)
        } else {
            return true
        }
    }
    .compactMap {
        updateItem(db: db, kind: kind, detail: $0)
    }
}

/// Holds a task and cancels it when released.
///
/// Kept in `@State`, it is released when the owning view's identity goes away
/// (e.g. the tab's view is torn down or the window closes) -- unlike
/// `onDisappear`, which also fires when a view is pushed on top in a
/// `NavigationStack`.
private final class TaskLifetime {
    var task: Task<Void, Never>? {
        willSet { task?.cancel() }
    }

    func cancel() {
        task?.cancel()
    }

    deinit {
        task?.cancel()
    }
}

/// An item for a detail that isn't in the db yet.
private func missingItem(db: Database, detail: DetailResult) -> UpdateItem {
    let games = db.matchName(detail.name)
    let gameIds = games.map { $0.id }.set()

    let mergeActions =
        games
        .flatMap {
            $0.shouldMergeDetail(detail)
        }

    let fix: UpdateItem.Fix =
        if mergeActions.isEmpty {
            .missing
        } else if mergeActions.count > 1 {
            .mergeMultiple
        } else if mergeActions[0].1 == MergeURLAction.add {
            .mergeURL
        } else {
            .replaceURL
        }

    return UpdateItem(detail: detail, gameIds: gameIds, fix: fix, db: db)
}

/// The update needed for a scanned detail: missing, a version change, or
/// `nil` if the db is up to date.
private func updateItem(
    db: Database, kind: GameResourceKind, detail: DetailResult
) -> UpdateItem? {
    if let match = db.existing(url: detail.url, kind: kind) {
        // existing file, check version
        guard let detailVersion = detail.version else { return nil }

        // compare canonically (1.0 == 1.00), store / show the clean form
        let canonicalNewVersion = canonicalVersion(detailVersion)
        let newVersion = cleanVersion(detailVersion)

        let files = match.filter { file in
            canonicalVersion(file.version) != canonicalNewVersion
        }

        guard let first = files.first else {
            // no mismatches
            return nil
        }

        let gameIds = files.map { $0.gameId }.set()
        let fileIds = files.map { $0.id }.set()
        let oldVersion = first.version ?? ""

        return UpdateItem(
            detail: detail, gameIds: gameIds,
            fix: .version(fileIds: fileIds, oldVersion: oldVersion, newVersion: newVersion),
            db: db)

    } else {
        // no existing file
        return missingItem(db: db, detail: detail)
    }
}

/// Navigation value for fixing an item.
private enum FixRoute: Hashable {
    /// choose the game first (zero or multiple candidates)
    case pickGame(UpdateItem, HTTPClient, GameResourceKind)
    /// create a new game for the item
    case newGame(UpdateItem, HTTPClient, GameResourceKind)
    /// edit for a known (or new) game
    case edit(EditTarget)
    /// edit an existing resource (bypassing a version fix)
    case editExisting(UpdateItem, HTTPClient, resourceId: String)

    static let pickGameTag = "pickGame"

    /// ``KindRoute/tag`` for the screen.
    var tag: String {
        switch self {
        case .pickGame: Self.pickGameTag
        case .newGame: "newGame"
        case .edit: "edit"
        case .editExisting: "editExisting"
        }
    }

    static func == (lhs: FixRoute, rhs: FixRoute) -> Bool {
        switch (lhs, rhs) {
        case (.pickGame(let a, let c1, let k1), .pickGame(let b, let c2, let k2)):
            a == b && c1 === c2 && k1 == k2
        case (.newGame(let a, let c1, let k1), .newGame(let b, let c2, let k2)):
            a == b && c1 === c2 && k1 == k2
        case (.edit(let a), .edit(let b)): a == b
        case (.editExisting(let a, let c1, let r1), .editExisting(let b, let c2, let r2)):
            a == b && c1 === c2 && r1 == r2
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .pickGame(let item, _, let kind):
            hasher.combine(0)
            hasher.combine(item)
            hasher.combine(kind)
        case .newGame(let item, _, let kind):
            hasher.combine(2)
            hasher.combine(item)
            hasher.combine(kind)
        case .edit(let target):
            hasher.combine(1)
            hasher.combine(target)
        case .editExisting(let item, _, let resourceId):
            hasher.combine(3)
            hasher.combine(item)
            hasher.combine(resourceId)
        }
    }
}

/// Navigation value for the editor.
private struct EditTarget: Hashable {
    let item: UpdateItem

    /// The game(s) to add to -- may be a new game, not yet in the db.
    let games: [Game]

    let client: HTTPClient

    /// The kind to create -- normally the view's kind, but can be changed
    /// for items that are miscategorized on the site.
    let kind: GameResourceKind

    /// The item's detail, as the target kind.
    var detail: DetailResult {
        var detail = item.detail
        detail.kind = kind
        return detail
    }

    /// Re-target as another kind -- only the first game if that kind can't
    /// be saved for multiple games.
    func with(kind: GameResourceKind) -> EditTarget {
        let multiple = editableType(for: kind)?.supportsMultipleGames ?? false
        return EditTarget(
            item: item, games: multiple ? games : Array(games.prefix(1)), client: client,
            kind: kind)
    }

    static func == (lhs: EditTarget, rhs: EditTarget) -> Bool {
        lhs.item == rhs.item && lhs.games.map(\.id) == rhs.games.map(\.id)
            && lhs.client === rhs.client && lhs.kind == rhs.kind
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(item)
        hasher.combine(games.map(\.id))
        hasher.combine(kind)
    }
}

/// A note on an item left in the list by bulk approve.
private struct ItemNote {
    let message: String
    let isError: Bool
}

private struct ApproveProgress {
    var done: Int
    let total: Int
}

private struct UpdateItem: Identifiable, Hashable {
    let id = UUID()

    let detail: DetailResult

    let gameIds: Set<String>

    /// `Name (Manufacturer Year)` for a single matching game, else e.g. `3 games`.
    let gameLabel: String

    enum GameMatch: Hashable {
        /// one game, and its name matches the item's name
        case exact
        /// one game, from a fuzzy name match
        case fuzzy
        /// zero or several games
        case unmatched
    }

    let gameMatch: GameMatch

    init(detail: DetailResult, gameIds: Set<String>, fix: Fix, db: Database) {
        self.detail = detail
        self.gameIds = gameIds
        self.fix = fix

        if gameIds.count == 1, let id = gameIds.first, let game = db.games[id] {
            let year = game.year.map { " \($0)" } ?? ""
            gameLabel = "\(game.name) (\(game.manufacturer.rawValue)\(year))"

            func canonical(_ string: String) -> String {
                String(string.lowercased().filter { $0.isLetter || $0.isNumber })
            }
            gameMatch =
                canonical(ParsedGameName(detail.name).name) == canonical(game.name)
                ? .exact : .fuzzy
        } else {
            gameLabel = gameIds.isEmpty ? "—" : "\(gameIds.count) games"
            gameMatch = .unmatched
        }
    }

    enum Fix: Hashable {
        case missing
        case mergeURL
        case replaceURL
        case mergeMultiple
        case version(fileIds: Set<String>, oldVersion: String, newVersion: String)
    }

    let fix: Fix

    var issue: String {
        switch fix {
        case .missing: "Missing"
        case .mergeURL: "Merge URL"
        case .replaceURL: "Replace URL"
        case .mergeMultiple: "Merge Multiple"
        case .version(_, let oldVersion, let newVersion):
            "Version \(oldVersion) → \(newVersion)"
        }
    }
}
