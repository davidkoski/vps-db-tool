import SwiftUI
import VPSDB

/// Table of ``Database/search(kind:query:)`` results for a single kind.
///
/// For game resources (everything but games) also shows the authors, comment and URL.
struct SearchResultsView: View {
    let db: Database
    let kind: GameResourceKind
    let query: String

    /// Called when a row is selected.
    var onSelect: (SearchResult) -> Void = { _ in }

    @State private var rows = [Row]()
    @State private var selection: Row.ID?
    @State private var sortOrder = [
        KeyPathComparator(\Row.result.game.name, comparator: .localizedStandard)
    ]

    var body: some View {
        // VPSDB also has a `Table` type
        SwiftUI.Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.result.game.name, comparator: .localizedStandard) { row in
                Text(row.result.game.name)
            }
            TableColumn(
                "Manufacturer", value: \.result.game.manufacturer.rawValue,
                comparator: .localizedStandard
            ) { row in
                Text(row.result.game.manufacturer.rawValue)
            }
            TableColumn("Year", value: \.sortableYear) { row in
                // avoid locale grouping ("1,995")
                Text(row.result.game.year.map(String.init) ?? "")
            }
            .width(min: 40, ideal: 60, max: 80)

            if kind != .game {
                TableColumn("Authors", value: \.authors, comparator: .localizedStandard) { row in
                    Text(row.authors)
                        .help(row.authors)
                }
                TableColumn("Comment", value: \.comment, comparator: .localizedStandard) { row in
                    Text(row.comment)
                        .lineLimit(1)
                        .help(row.comment)
                }
                .width(min: 100, ideal: 250)
                TableColumn("URL", value: \.urlString, comparator: .localizedStandard) { row in
                    if let url = row.url {
                        Link(row.urlString, destination: url)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(row.urlString)
                    }
                }
                .width(min: 100, ideal: 250)
            }
        }
        .onChange(of: sortOrder) { _, sortOrder in
            rows.sort(using: sortOrder)
        }
        .onChange(of: selection) { _, id in
            guard let id, let row = rows.first(where: { $0.id == id }) else { return }
            onSelect(row.result)
            // clear so the same row can be selected again after navigating back
            selection = nil
        }
        .task(id: query) {
            // debounce: a new query cancels this task (and the sleep) before it searches
            let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                rows = []
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
            rows = db.search(kind: kind, query: query)
                .map { Row(result: $0, resource: db.gameResource(kind: $0.kind, id: $0.id)) }
                .sorted(using: sortOrder)
        }
    }
}

/// A search result with the display (and sort) values of its resource.
private struct Row: Identifiable {
    let result: SearchResult

    /// Author names, comma separated -- empty for games.
    let authors: String

    /// The comment on a single line -- empty for games.
    let comment: String

    /// The first URL of the resource -- nil for games.
    let url: URL?

    /// `url` as a string for display and sorting -- empty if there is no url.
    var urlString: String { url?.absoluteString ?? "" }

    var id: SearchResult.ID { result.id }

    /// `year` is optional (not `Comparable`) -- sort unknown years first.
    var sortableYear: Int { result.game.year ?? 0 }

    init(result: SearchResult, resource: (any GameResource)?) {
        self.result = result
        let common = resource?.gameResource
        self.url = resource?.url
        self.authors = common?.authors.map(\.name).joined(separator: ", ") ?? ""
        self.comment = (common?.comment ?? "")
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
    }
}

#Preview {
    SearchResultsView(db: Database(), kind: .table, query: "addams")
}
