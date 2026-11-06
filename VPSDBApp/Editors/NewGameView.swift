import SwiftUI
import VPSDB

/// Collect the details for a new game.
struct NewGameView: View {
    /// What the game is being created for (for reference) -- e.g. the
    /// scanned item's name and page.
    let sourceName: String
    let sourceURL: URL?

    /// IPDB entries, for looking up the game (empty if not configured).
    let ipdb: IPDB

    /// The database, for completions (e.g. designers).
    let db: Database

    /// Called with the new game -- not yet saved to the db.
    let onCreate: (Game) -> Void

    @State private var name: String
    @State private var manufacturer: String
    @State private var year: String
    @State private var type: Kind?
    @State private var players = ""
    @State private var designers = [String]()
    @State private var themes = [String]()

    /// IPDB url, or a machine number (converted to the url on return).
    @State private var ipdbText = ""

    /// IPDB entries matching the name / manufacturer / year (debounced).
    @State private var ipdbMatches = [IPDB.Entry]()

    /// Manufacturer names for completion.
    @State private var manufacturerNames = Lazy {
        Manufacturer.allCases
            .filter { $0 != .missing && $0 != .unknown }
            .map(\.rawValue)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    @State private var designerNames: Lazy<[String]>

    @State private var themeNames = Lazy { Theme.allCases.sorted().map(\.rawValue) }

    /// Max IPDB matches to show.
    private let matchLimit = 25

    /// A game for a scanned item -- prefilled from its name.
    init(
        detail: DetailResult, ipdb: IPDB, db: Database, onCreate: @escaping (Game) -> Void
    ) {
        self.init(
            sourceName: detail.name, sourceURL: detail.url, prefill: detail.name, ipdb: ipdb,
            db: db, onCreate: onCreate)
    }

    /// A game for `sourceName` (shown for reference), with the name,
    /// manufacturer and year parsed from `prefill` ("NAME (Manufacturer Year)").
    init(
        sourceName: String, sourceURL: URL?, prefill: String, ipdb: IPDB, db: Database,
        onCreate: @escaping (Game) -> Void
    ) {
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.ipdb = ipdb
        self.db = db
        self.onCreate = onCreate

        // "NAME (Manufacturer Year)" -- prefill what we can
        let parsed = ParsedGameName(prefill)
        self._name = State(initialValue: parsed.name)
        self._manufacturer = State(initialValue: parsed.manufacturer?.rawValue ?? "")
        self._year = State(initialValue: parsed.year.map(String.init) ?? "")

        self._designerNames = State(initialValue: Lazy { db.designers() })
    }

    var body: some View {
        DetailForm {
            Section {
                HStack {
                    Text(sourceName)
                        .textSelection(.enabled)
                    if let sourceURL {
                        OpenURLButton(url: sourceURL)
                    }
                }
            } header: {
                Text("Creating a game for")
            }

            Section("Game") {
                TextField("Name", text: $name)

                LabeledContent("Manufacturer") {
                    VStack(alignment: .trailing) {
                        CompletingTextField(
                            title: "Manufacturer", text: $manufacturer,
                            candidates: manufacturerNames
                        )
                        .labelsHidden()
                        if manufacturerValue == nil {
                            invalid("Unknown manufacturer")
                        }
                    }
                }

                LabeledContent("Year") {
                    VStack(alignment: .trailing) {
                        TextField("Year", text: $year)
                            .labelsHidden()
                        if yearValue == nil {
                            invalid("Year must be a number")
                        }
                    }
                }

                Picker("Type", selection: $type) {
                    Text("—").tag(Kind?.none)
                    ForEach(Kind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(Kind?.some(kind))
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Players") {
                    VStack(alignment: .trailing) {
                        TextField("Players", text: $players)
                            .labelsHidden()
                        if playersValue == nil {
                            invalid("Players must be a number")
                        }
                    }
                }
            }

            ipdbSection

            Section("Designers") {
                TokenField(title: "Designer", values: $designers, candidates: designerNames)
            }

            Section("Themes") {
                TokenField(title: "Theme", values: $themes, candidates: themeNames) { text in
                    // only known themes
                    Self.theme(text)?.rawValue
                }
            }
        }
        .navigationTitle("New Game")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Create (⌘↩)")
                    .disabled(!isValid)
            }
        }
        .task(id: ipdbQuery) {
            // debounce: a new query cancels this task (and the sleep) before it searches
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
            let query = ipdbQuery
            ipdbMatches =
                query.name.count < 2
                ? []
                : ipdb.search(name: query.name, manufacturer: query.manufacturer, year: query.year)
        }
    }

    // MARK: - IPDB

    @ViewBuilder
    private var ipdbSection: some View {
        Section {
            LabeledContent("IPDB") {
                VStack(alignment: .trailing) {
                    HStack {
                        TextField("IPDB url or number", text: $ipdbText)
                            .labelsHidden()
                            .onSubmit(submitIPDB)
                        if let url = ipdbURLValue ?? nil {
                            OpenURLButton(url: url)
                        }
                    }
                    if ipdbURLValue == nil {
                        invalid("Not an IPDB url or number")
                    } else if let entry = selectedEntry {
                        Text("\(entry.name) · \(entry.manufacturerName) · \(String(entry.year))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if ipdb.entries.isEmpty {
                Text("No IPDB file configured in Settings")
                    .foregroundStyle(.secondary)
            } else if !ipdbMatches.isEmpty {
                ForEach(ipdbMatches.prefix(matchLimit), id: \.id) { entry in
                    ipdbRow(entry)
                }
                if ipdbMatches.count > matchLimit {
                    Text("\(ipdbMatches.count - matchLimit) more…")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("IPDB")
        }
    }

    private func ipdbRow(_ entry: IPDB.Entry) -> some View {
        Button {
            select(entry)
        } label: {
            HStack {
                Image(systemName: "checkmark")
                    .opacity(entry.id == selectedEntry?.id ? 1 : 0)
                Text(entry.id)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
                Text(entry.name)
                Spacer()
                Text(entry.manufacturerName)
                    .foregroundStyle(.secondary)
                Text(String(entry.year))
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The inputs to the IPDB search.
    private struct IPDBQuery: Hashable {
        let name: String
        let manufacturer: Manufacturer?
        let year: Int?
    }

    private var ipdbQuery: IPDBQuery {
        IPDBQuery(
            name: trimmedName,
            // only narrow by a manufacturer that was actually entered
            manufacturer: manufacturerValue == .unknown ? nil : manufacturerValue,
            year: yearValue ?? nil)
    }

    private static func ipdbURL(id: String) -> URL? {
        URL(string: "http://www.ipdb.org/machine.cgi?id=\(id)")
    }

    private static func ipdbId(_ url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "id" }?.value
    }

    /// The IPDB url: `.some(nil)` if empty, `nil` if invalid.
    private var ipdbURLValue: URL?? {
        let text = ipdbText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return .some(nil)
        }
        if Int(text) != nil {
            return Self.ipdbURL(id: text)
        }
        if let url = URL(string: text), url.host()?.hasSuffix("ipdb.org") == true,
            Self.ipdbId(url) != nil
        {
            return url
        }
        return nil
    }

    /// The IPDB entry for the current url, if it's in the list.
    private var selectedEntry: IPDB.Entry? {
        guard let url = ipdbURLValue ?? nil, let id = Self.ipdbId(url) else { return nil }
        return ipdb.entries[id]
    }

    private func select(_ entry: IPDB.Entry) {
        ipdbText = Self.ipdbURL(id: entry.id)?.absoluteString ?? ""
        fillEmptyFields(from: entry)
    }

    /// Fill in fields the user hasn't set from the IPDB entry.
    private func fillEmptyFields(from entry: IPDB.Entry) {
        func isEmpty(_ text: String) -> Bool {
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if isEmpty(manufacturer), entry.manufacturer != .unknown, entry.manufacturer != .missing {
            manufacturer = entry.manufacturer.rawValue
        }
        if isEmpty(year), entry.year > 0 {
            year = String(entry.year)
        }
        if type == nil, let kind = entry.kind {
            type = kind
        }
        if isEmpty(players), entry.players > 0 {
            players = String(entry.players)
        }
        if !entry.themes.isEmpty {
            themes.append(contentsOf: entry.themes.map { $0.rawValue })
        }
    }

    /// Return in the IPDB field: a machine number becomes its url (and selects
    /// the entry, if present).
    private func submitIPDB() {
        let text = ipdbText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Int(text) != nil, let url = Self.ipdbURL(id: text) else { return }
        ipdbText = url.absoluteString
        if let entry = ipdb.entries[text] {
            fillEmptyFields(from: entry)
        }
    }

    // MARK: - Validation

    private func invalid(_ message: LocalizedStringKey) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The manufacturer: `.unknown` if empty, `nil` if it doesn't match one.
    private var manufacturerValue: Manufacturer? {
        let text = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return .unknown
        }
        return Manufacturer.allCases.first {
            $0.rawValue.caseInsensitiveCompare(text) == .orderedSame
        }
    }

    private static func theme(_ text: String) -> Theme? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Theme.allCases.first { $0.rawValue.caseInsensitiveCompare(text) == .orderedSame }
    }

    /// Parse an optional integer field: `.some(nil)` if empty, `nil` if invalid.
    private func optionalInt(_ text: String) -> Int?? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return .some(nil)
        }
        guard let value = Int(text), value > 0 else { return nil }
        return .some(value)
    }

    private var yearValue: Int?? { optionalInt(year) }
    private var playersValue: Int?? { optionalInt(players) }

    private var isValid: Bool {
        !trimmedName.isEmpty && manufacturerValue != nil && yearValue != nil
            && playersValue != nil && ipdbURLValue != nil
    }

    private func create() {
        guard isValid,
            let manufacturer = manufacturerValue,
            let year = yearValue,
            let players = playersValue,
            let ipdbURL = ipdbURLValue
        else { return }

        onCreate(
            Game(
                name: trimmedName,
                manufacturer: manufacturer,
                year: year,
                type: type,
                players: players,
                ipdbUrl: ipdbURL,
                designers: designers,
                themes: themes.compactMap(Self.theme)))
    }
}

#Preview {
    NavigationStack {
        NewGameView(
            detail: DetailResult(
                .list,
                url: URL(string: "https://vpuniverse.com/files/file/1234")!,
                kind: .table, name: "Example Table (Williams 1990)", author: "Someone"),
            ipdb: IPDB(),
            db: Database(),
            onCreate: { _ in })
    }
}
