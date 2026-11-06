import Logging
import SwiftUI
import VPSDB

private let log = Logger(label: "ChecksView")

/// Checks for a single kind: run a check, then fix the resources it finds --
/// each fix is proposed in the editor for review.
struct ChecksView: View {
    /// Holds the suppressed check results.
    let document: VPSDBDocument

    @Binding var db: Database
    let kind: GameResourceKind

    @Environment(AppSettings.self) private var settings

    /// Client for the fixes' page fetches.
    @State private var client: HTTPClient?

    /// The selected check's ``ResourceCheck/id``.
    @AppStorage private var checkId: String

    @State private var items = [CheckItem]()
    @State private var hasRun = false
    @State private var selection = Set<CheckItem.ID>()

    /// Items with a fix in progress.
    @State private var fixing = Set<CheckItem.ID>()

    /// Why a fix failed, by item.
    @State private var errors = [CheckItem.ID: String]()

    /// Items that no longer need a fix (fixed since the check ran, or gone).
    @State private var resolved = Set<CheckItem.ID>()

    /// Items bulk apply left for review, with why.
    @State private var needsReview = [CheckItem.ID: String]()

    /// The running bulk apply, and its progress.
    @State private var applyTask: Task<Void, Never>?
    @State private var applyProgress: (done: Int, total: Int)?

    /// The kind's navigation path -- proposals are reviewed in an editor
    /// pushed onto it.
    @Binding var path: [KindRoute]

    /// The toolbar search text -- shows only items whose columns contain it.
    let query: String

    @State private var sortOrder = [
        KeyPathComparator(\CheckItem.gameName, comparator: .localizedStandard)
    ]

    init(
        document: VPSDBDocument, db: Binding<Database>, kind: GameResourceKind,
        query: String = "", path: Binding<[KindRoute]>
    ) {
        self.document = document
        self.query = query
        self._db = db
        self.kind = kind
        self._path = path
        self._checkId = AppStorage(wrappedValue: "", "checkId.\(kind.rawValue)")
    }

    private var available: [any ResourceCheck] {
        checks(for: kind)
    }

    private var check: (any ResourceCheck)? {
        available.first { $0.id == checkId } ?? available.first
    }

    var body: some View {
        if available.isEmpty {
            ContentUnavailableView(
                "No Checks", systemImage: "checklist",
                description: Text("There are no checks for \(kind.rawValue)"))
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Check", selection: $checkId) {
                    ForEach(available, id: \.id) { check in
                        Text(check.name).tag(check.id)
                    }
                }
                .fixedSize()
                .onChange(of: checkId) {
                    items = []
                    hasRun = false
                }

                Button("Run", systemImage: "play") { runCheck() }

                if hasRun {
                    let shown = visibleItems.count
                    Group {
                        if shown == items.count {
                            Text("^[\(items.count) item](inflect: true)")
                        } else {
                            Text("\(shown) of ^[\(items.count) item](inflect: true)")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                let suppressedCount = suppressions.count
                if suppressedCount > 0 {
                    Menu("\(suppressedCount) Suppressed") {
                        Button("Unsuppress All") { unsuppressAll() }
                    }
                    .fixedSize()
                    .help("Results of this check that are suppressed (not shown)")
                }
                Spacer()

                if let applyProgress {
                    ProgressView(
                        value: Double(applyProgress.done), total: Double(applyProgress.total)
                    ) {
                        Text("Applying \(applyProgress.done + 1) of \(applyProgress.total)…")
                    }
                    .frame(width: 200)
                    Button("Cancel") { applyTask?.cancel() }
                } else if check?.supportsBulkApply ?? false {
                    Button("Apply Selected (\(selection.count))", systemImage: "checkmark.circle") {
                        apply(selection)
                    }
                    .disabled(selection.isEmpty || client == nil)
                    .help("Fix the selected items without review -- items that need review stay")
                }
            }

            SwiftUI.Table(visibleItems, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Game", value: \.gameName, comparator: .localizedStandard) { item in
                    Text(item.gameName)
                }
                TableColumn("Version", value: \.version, comparator: .localizedStandard) { item in
                    Text(item.version)
                }
                .width(min: 50, ideal: 70)
                TableColumn("Authors", value: \.authors, comparator: .localizedStandard) { item in
                    Text(item.authors)
                }
                TableColumn("Created", value: \.sortableCreatedAt) { item in
                    if let createdAt = item.createdAt {
                        Text(createdAt, format: .dateTime.year().month().day())
                    }
                }
                .width(min: 70, ideal: 90)
                TableColumn("Problems", value: \.problemsText, comparator: .localizedStandard) {
                    item in
                    Text(item.problemsText)
                }
                TableColumn("Status") { item in
                    if fixing.contains(item.id) {
                        ProgressView()
                            .controlSize(.small)
                    } else if resolved.contains(item.id) {
                        Text("Already fixed")
                            .foregroundStyle(.secondary)
                    } else if let note = needsReview[item.id] {
                        Text(note)
                            .foregroundStyle(.secondary)
                            .help(note)
                    } else if let error = errors[item.id] {
                        Text(error)
                            .foregroundStyle(.red)
                            .help(error)
                    }
                }
            }
            .contextMenu(forSelectionType: CheckItem.ID.self) { ids in
                if ids.count == 1, let item = items.first(where: { ids.contains($0.id) }) {
                    Button("Fix…") { fix(item) }
                    Button("Edit Without Fix…") { editWithoutFix(item) }
                    Divider()
                    Button("Suppress") { suppress(ids) }
                        .help("Don't show this result of the check again")
                    Button("Remove") { remove(ids) }
                } else if ids.count > 1 {
                    if check?.supportsBulkApply ?? false {
                        Button("Apply \(ids.count) Selected") { apply(ids) }
                            .disabled(applyProgress != nil || client == nil)
                    }
                    Button("Suppress \(ids.count) Items") { suppress(ids) }
                    Button("Remove \(ids.count) Items") { remove(ids) }
                }
            } primaryAction: { ids in
                // Return or double-click
                if ids.count == 1, let item = items.first(where: { ids.contains($0.id) }) {
                    fix(item)
                }
            }
            .onDeleteCommand {
                remove(selection)
            }
        }
        .padding()
        .onChange(of: settings.cacheURL, initial: true) { _, cacheURL in
            client = HTTPClient(cache: cacheURL, throttle: .seconds(2))
        }
        .onChange(of: sortOrder) { _, sortOrder in
            items.sort(using: sortOrder)
        }
        .onChange(of: query) {
            // actions apply to the selection -- keep it to the rows shown
            selection.formIntersection(visibleItems.map(\.id))
        }
    }

    /// The items matching the search text (in the columns' text, including
    /// the status).
    private var visibleItems: [CheckItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return items }
        return items.filter { item in
            matchesQuery(
                query,
                [
                    item.gameName, item.version, item.authors,
                    item.createdAt?.formatted(.dateTime.year().month().day()),
                    item.problemsText, statusText(item),
                ])
        }
    }

    /// The text of the Status column (for searching).
    private func statusText(_ item: CheckItem) -> String? {
        if resolved.contains(item.id) {
            "Already fixed"
        } else if let note = needsReview[item.id] {
            note
        } else {
            errors[item.id]
        }
    }

    /// Review a proposal in the editor (or its custom UI).
    ///
    /// Fixes start from this view (the stack's root), so the path should be
    /// empty -- if it isn't, its entries are stale (not on screen: a pop that
    /// didn't update the path) and are dropped rather than pushed onto.
    private func show(_ route: CheckRoute) {
        navLog.info("NAV [\(kind)] checks show \(route.item.id), path \(path.map(\.debugName))")
        let screen = KindRoute.view("checkProposal") { self.editor(route) }
        if path.isEmpty {
            path.append(screen)
        } else {
            log.warning("stale navigation path \(path.map(\.debugName)) -- resetting")
            path = [screen]
        }
    }

    private func runCheck() {
        guard let client else { return }
        guard let check else { return }
        let context = CheckContext(db: db, settings: settings, client: client)
        let suppressed = document.model.suppressedChecks
        items = run(check, kind: kind, context: context)
            .filter { !suppressed.contains(suppression(for: $0, check: check)) }
            .sorted(using: sortOrder)
        errors = [:]
        resolved = []
        needsReview = [:]
        hasRun = true
        log.info("\(check.name) on \(kind): \(items.count) items")
    }

    private func remove(_ ids: Set<CheckItem.ID>) {
        items.removeAll { ids.contains($0.id) }
    }

    // MARK: - Suppression

    private func suppression(for item: CheckItem, check: any ResourceCheck) -> CheckSuppression {
        CheckSuppression(
            kind: item.kind, resourceId: item.resourceId, checkId: check.id,
            checkVersion: check.version)
    }

    /// The suppressions for the selected check (its current version) and kind.
    private var suppressions: [CheckSuppression] {
        guard let check else { return [] }
        return document.model.suppressedChecks.filter {
            $0.checkId == check.id && $0.checkVersion == check.version && $0.kind == kind
        }
    }

    /// Record suppressions in the document and take the items off the list.
    private func suppress(_ ids: Set<CheckItem.ID>) {
        guard let check else { return }
        for item in items where ids.contains(item.id) {
            document.model.suppressedChecks.insert(suppression(for: item, check: check))
        }
        log.info("suppressed \(ids.count) \(check.name) results")
        remove(ids)
        selection.subtract(ids)
    }

    /// Remove this check's suppressions (for this kind) -- run the check again
    /// to see the items.
    private func unsuppressAll() {
        let all = Set(suppressions)
        document.model.suppressedChecks.subtract(all)
        log.info("unsuppressed \(all.count) results")
        if hasRun {
            runCheck()
        }
    }

    /// Run the item's fix, then review the proposal in the editor.
    private func fix(_ item: CheckItem) {
        guard let client, !fixing.contains(item.id) else { return }

        let context = CheckContext(db: db, settings: settings, client: client)
        
        // e.g. fixed along with another resource of the same game
        guard item.stillApplies(context: context) else {
            navLog.info("NAV [\(kind)] checks fix \(item.id): no longer applies")
            resolved.insert(item.id)
            return
        }

        fixing.insert(item.id)
        errors[item.id] = nil
        Task {
            defer { fixing.remove(item.id) }
            do {
                if let proposal = try await item.fix(context: context) {
                    show(CheckRoute(item: item, proposal: proposal))
                } else {
                    resolved.insert(item.id)
                }
            } catch {
                log.info("fix \(item.id) failed: \(error)")
                errors[item.id] = error.localizedDescription
            }
        }
    }

    /// Open the editor on the resource as is.
    private func editWithoutFix(_ item: CheckItem) {
        guard let resource = item.resource(in: db) else {
            resolved.insert(item.id)
            return
        }
        show(
            CheckRoute(
                item: item, proposal: FixProposal(resource: resource, detail: nil, changes: [])))
    }

    /// Fix `ids` without review, one at a time: each is re-checked and its fix
    /// proposed against the current db, then applied (see
    /// ``FixProposal/apply(_:)``).  Items that need review or fail stay in the
    /// list with a note.
    private func apply(_ ids: Set<CheckItem.ID>) {
        guard let client, applyProgress == nil else { return }
        // in list order
        let targets = items.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return }

        applyProgress = (0, targets.count)
        applyTask = Task {
            defer {
                applyProgress = nil
                applyTask = nil
                recheck()
            }
            var applied = 0
            for (index, item) in targets.enumerated() {
                if Task.isCancelled { break }
                applyProgress = (index, targets.count)
                errors[item.id] = nil
                needsReview[item.id] = nil

                // the current db -- earlier items may have changed it
                let context = CheckContext(db: db, settings: settings, client: client)
                guard item.stillApplies(context: context) else {
                    resolved.insert(item.id)
                    continue
                }
                fixing.insert(item.id)
                defer { fixing.remove(item.id) }
                do {
                    guard let proposal = try await item.fix(context: context) else {
                        resolved.insert(item.id)
                        continue
                    }
                    let env = CustomFixEnvironment(
                        item: item, db: $db, settings: settings, client: client,
                        done: { _ in })
                    switch try await proposal.apply(env) {
                    case .applied:
                        items.removeAll { $0.id == item.id }
                        selection.remove(item.id)
                        applied += 1
                    case .needsReview(let reason):
                        needsReview[item.id] = reason
                    }
                } catch {
                    log.info("apply \(item.id) failed: \(error)")
                    errors[item.id] = error.localizedDescription
                }
            }
            log.info("bulk apply: \(applied) of \(targets.count) applied")
        }
    }

    /// Drop items that no longer have problems -- e.g. fixed along with others.
    private func recheck() {
        guard let client else { return }
        let context = CheckContext(db: db, settings: settings, client: client)
        let before = items.count
        items.removeAll { !$0.stillApplies(context: context) }
        if items.count != before {
            log.info("\(before - items.count) other items no longer have problems")
        }
    }

    /// After a successful fix: back to the list, without the item -- and
    /// without any other items no longer having problems (a fix, e.g. a
    /// custom one, can change several games).
    private func fixed(_ item: CheckItem) {
        navLog.info("NAV [\(kind)] checks fixed \(item.id), path \(path.map(\.debugName))")
        items.removeAll { $0.id == item.id }
        recheck()
        // started at this view (the stack's root)
        path.removeAll()
        navLog.info("NAV [\(kind)] checks fixed after removeAll, path \(path.map(\.debugName))")
    }

    @ViewBuilder
    private func editor(_ route: CheckRoute) -> some View {
        switch route.proposal.action {
        case .edit(let resource, let detail, let changes):
            // the game it was found in (saving there also corrects the resource's game ref)
            if let client, let game = route.item.game(in: db) {
                KindEditorView(
                    db: $db, kind: route.item.kind, detail: detail, games: [game],
                    client: client, resource: resource
                ) { disposition in
                    navLog.info("NAV [\(kind)] checks editor onDone \(disposition)")
                    switch disposition {
                    case .ok, .replacedObsolete:
                        fixed(route.item)
                    case .failed:
                        // stay in the editor so the edits aren't lost
                        break
                    }
                }
                .environment(\.proposedChanges, changes)
            } else {
                ContentUnavailableView(
                    "Not Found", systemImage: "questionmark.folder",
                    description: Text("No game for \(resource.id)"))
            }

        case .custom(let fix):
            if let client {
                fix.content(
                    CustomFixEnvironment(
                        item: route.item, db: $db, settings: settings, client: client,
                        done: { didFix in
                            if didFix {
                                fixed(route.item)
                            } else {
                                path.removeAll()
                            }
                        })
                )
                .navigationTitle(fix.title)
            }
        }
    }
}

/// A proposal to review -- see ``ChecksView/show(_:)``.
private struct CheckRoute {
    let item: CheckItem
    let proposal: FixProposal
}

extension CheckItem {
    /// For sorting -- no date sorts first.
    fileprivate var sortableCreatedAt: Date { createdAt ?? .distantPast }

    fileprivate var problemsText: String { problems.joined(separator: ", ") }
}
