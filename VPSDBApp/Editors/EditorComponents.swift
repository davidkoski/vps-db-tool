import SwiftUI
import VPSDB

/// Editable list of values with add / remove controls.
///
/// Row bindings are bounds-checked so removing an element doesn't crash
/// a row that SwiftUI hasn't torn down yet.
struct EditableList<Element, Row: View>: View {
    let title: LocalizedStringKey
    @Binding var elements: [Element]
    let newElement: () -> Element
    @ViewBuilder let row: (Binding<Element>) -> Row

    var body: some View {
        Section {
            ForEach(elements.indices, id: \.self) { index in
                HStack {
                    row(binding(index))
                    Button("Remove", systemImage: "minus.circle") {
                        if elements.indices.contains(index) {
                            elements.remove(at: index)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Button("Add", systemImage: "plus.circle") {
                    elements.append(newElement())
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
    }

    private func binding(_ index: Int) -> Binding<Element> {
        Binding {
            elements.indices.contains(index) ? elements[index] : newElement()
        } set: { newValue in
            if elements.indices.contains(index) {
                elements[index] = newValue
            }
        }
    }
}

/// Small button that opens a URL in the default browser.
struct OpenURLButton: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label("Open in Browser", systemImage: "safari")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help(url.absoluteString)
    }
}

/// Section showing thumbnails for a list of image URLs.
///
/// Clicking a thumbnail opens the full image in the browser.
struct ImageThumbnailsSection: View {
    let title: LocalizedStringKey
    let urls: [URL]
    var size: CGFloat = 120

    init(_ title: LocalizedStringKey = "Images", urls: [URL], size: CGFloat = 120) {
        self.title = title
        self.urls = urls
        self.size = size
    }

    var body: some View {
        if !urls.isEmpty {
            Section(title) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: size, maximum: size))],
                    alignment: .leading
                ) {
                    ForEach(urls, id: \.self) { url in
                        Link(destination: url) {
                            thumbnail(url)
                        }
                        .buttonStyle(.plain)
                        .help(url.absoluteString)
                    }
                }
            }
        }
    }

    private func thumbnail(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            default:
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// The resource's current image (e.g. a backglass or table image) -- read
/// from the local images directory (``AppSettings/imagesURL`` + the image's
/// file name), falling back to the published URL.
struct CurrentImageSection: View {
    var title: LocalizedStringKey = "Current Image"
    let url: URL

    /// Max height of the image.
    var height: CGFloat = 300

    @Environment(AppSettings.self) private var settings

    @State private var image: NSImage?
    @State private var isMissing = false

    private var localURL: URL {
        settings.imagesURL.appending(path: url.lastPathComponent)
    }

    var body: some View {
        Section(title) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else if isMissing {
                    // not in the local images directory -- try the published copy
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Label("Image not found", systemImage: "photo.badge.exclamationmark")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: height)

            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .help(isMissing ? url.absoluteString : localURL.path(percentEncoded: false))
        }
        .task(id: url) {
            let localURL = localURL
            let loaded = await Task.detached { NSImage(contentsOf: localURL) }.value
            image = loaded
            isMissing = loaded == nil
        }
    }
}

/// A value computed on first access and then cached.
///
/// A reference type, so it can be read during `body` without mutating view
/// state (and without triggering updates).
@MainActor
final class Lazy<Value> {
    private var value: Value?
    private let make: () -> Value

    init(_ make: @escaping () -> Value) {
        self.make = make
    }

    var wrappedValue: Value {
        if let value {
            return value
        }
        let value = make()
        self.value = value
        return value
    }
}

/// Text field that suggests completions from a (lazily loaded) list of values.
struct CompletingTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let candidates: Lazy<[String]>
    var limit = 10

    var body: some View {
        TextField(title, text: $text)
            .textInputSuggestions {
                ForEach(suggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .textInputCompletion(suggestion)
                }
            }
    }

    /// Prefix matches first, then other substring matches.  Nothing until the
    /// user types, so the candidates aren't loaded just by showing the field.
    private var suggestions: [String] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }

        var prefix = [String]()
        var contains = [String]()
        for candidate in candidates.wrappedValue {
            if candidate.compare(query, options: [.caseInsensitive, .diacriticInsensitive])
                == .orderedSame
            {
                // exact match -- nothing to complete
                return []
            }
            if let range = candidate.range(
                of: query, options: [.caseInsensitive, .diacriticInsensitive])
            {
                if range.lowerBound == candidate.startIndex {
                    prefix.append(candidate)
                } else {
                    contains.append(candidate)
                }
            }
        }
        return Array((prefix + contains).prefix(limit))
    }
}

/// Highlighted suggestion to merge the edited resource's url into an existing
/// resource -- the same release, already in the db from another site.
///
/// There may be several candidates (e.g. the author has more than one release
/// of the game) -- each is shown with its own merge button.
struct MergeSuggestionSection<Resource: GameResource>: View {
    let newVersion: String?
    let newDate: Date?

    /// Existing items that may be the same release -- one section each.
    let candidates: [(Resource, MergeURLAction)]
    let onMerge: (Resource) -> Void

    var body: some View {
        ForEach(Array(candidates.enumerated()), id: \.element.0.id) { index, pair in
            let (candidate, action) = pair
            Section {
                if index == 0 {
                    HStack {
                        if let newVersion {
                            LabeledContent("Version") {
                                Text(newVersion)
                            }
                        }
                        if let newDate {
                            LabeledContent("Created") {
                                Text(newDate, format: .dateTime)
                            }
                        }
                    }
                    .bold()

                    Label(
                        candidates.count == 1
                            ? "This looks like an existing item from another site"
                            : "This looks like one of \(candidates.count) existing items from other sites",
                        systemImage: "arrow.triangle.merge"
                    )
                    .font(.headline)
                }

                candidateRows(candidate)

                HStack {
                    Spacer()
                    switch action {
                    case .add:
                        Button("Merge URL into Existing", systemImage: "arrow.triangle.merge") {
                            onMerge(candidate)
                        }
                        .help("Add this item's URL to this existing item and save it instead")
                    case .replace:
                        Button("Replace URL into Existing", systemImage: "arrow.triangle.merge") {
                            onMerge(candidate)
                        }
                        .help("Replace item URL and save it instead.")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .listRowBackground(Color.yellow.opacity(0.2))
        }
    }

    @ViewBuilder
    private func candidateRows(_ candidate: Resource) -> some View {
        let common = candidate.gameResource
        LabeledContent(
            "Authors", value: common.authors.map(\.name).joined(separator: ", "))
        OptionalRow("Version", candidate.version)
        if let comment = common.comment, !comment.isEmpty {
            LabeledContent("Comment") {
                Text(comment)
                    .textSelection(.enabled)
            }
        }
        LabeledContent("Created") { Text(common.createdAt, format: .dateTime) }
        ForEach(candidate.urls, id: \.self) { url in
            LabeledContent("URL") {
                Link(url.absoluteString, destination: url)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

/// Text field + removable tokens, e.g. designers or themes.
///
/// Type (with completion) and hit return to add a value; values show as
/// tokens below the field -- click one to remove it.
struct TokenField: View {
    let title: LocalizedStringKey
    @Binding var values: [String]
    let candidates: Lazy<[String]>

    /// Canonical form of an entered value, or `nil` to reject it
    /// (e.g. not a known theme).  Default: trimmed, non-empty.
    var normalize: (String) -> String? = { text in
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @State private var text = ""
    @State private var rejected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompletingTextField(title: title, text: $text, candidates: candidates)
                .labelsHidden()
                .textFieldStyle(.plain)
                .onSubmit(add)
                .onChange(of: text) { rejected = false }

            if rejected {
                Text("Unknown value")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !values.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            values.removeAll { $0 == value }
                        } label: {
                            HStack(spacing: 6) {
                                Text(value)
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(value)")
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.secondary.opacity(0.5))
        }
    }

    private func add() {
        guard let value = normalize(text) else {
            rejected = !text.trimmingCharacters(in: .whitespaces).isEmpty
            return
        }
        if !values.contains(value) {
            values.append(value)
        }
        text = ""
    }
}

/// Lays out its subviews left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indexes {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indexes = [Int]()
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row]()
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indexes.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indexes.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width =
                current.indexes.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indexes.append(index)
        }
        if !current.indexes.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// Section listing the games the edited resource will be saved for.
struct GameListSection: View {
    let games: [Game]

    var body: some View {
        Section("Games (\(games.count))") {
            ForEach(games, id: \.id) { game in
                GameRow(game: game)
            }
        }
    }
}

/// One line describing a game: name, manufacturer and year.
struct GameRow: View {
    let game: Game

    var body: some View {
        HStack {
            Text(game.name)
            Spacer()
            Text(game.manufacturer.rawValue)
                .foregroundStyle(.secondary)
            Text(game.year.map(String.init) ?? "")
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}

/// Section describing the game the edited resource belongs to.
struct GameSummarySection: View {
    let game: Game?
    let resource: any GameResource?

    var body: some View {
        Section("Game") {
            if let game {
                HStack {
                    Link(destination: game.vpsURL) {
                        Text(
                            "\(game.name) (\(game.manufacturer.rawValue) \((game.year ?? 0).description))"
                        )
                    }
                    if let resource {
                        Spacer()
                        Link(destination: resource.vpsURL) {
                            Text(resource.kind.rawValue)
                        }
                        if let url = resource.url {
                            Link(destination: url) {
                                Text(url.host() ?? "page")
                            }
                        }
                    }
                }
            } else {
                Text("Game not found")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension Binding where Value == String? {
    /// Maps an optional string to a non-optional one, storing empty as `nil`.
    var orEmpty: Binding<String> {
        Binding<String> {
            wrappedValue ?? ""
        } set: { newValue in
            wrappedValue = newValue.isEmpty ? nil : newValue
        }
    }
}

extension Binding where Value == URL? {
    /// Edit an optional URL as text: empty is `nil`, unparseable text is ignored.
    var text: Binding<String> {
        Binding<String> {
            wrappedValue?.absoluteString ?? ""
        } set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                wrappedValue = nil
            } else if let url = URL(string: trimmed) {
                wrappedValue = url
            }
        }
    }
}

extension Binding where Value == [Author] {
    /// Edit authors as plain strings.
    var names: Binding<[String]> {
        Binding<[String]> {
            wrappedValue.map(\.name)
        } set: { newValue in
            wrappedValue = newValue.map(Author.init(name:))
        }
    }
}

extension Binding where Value == [Resource] {
    /// Edit resources as plain URLs (preserving the `broken` flag by position).
    var urls: Binding<[URL]> {
        Binding<[URL]> {
            wrappedValue.map(\.url)
        } set: { newValue in
            let old = wrappedValue
            wrappedValue = newValue.enumerated().map { index, url in
                let broken =
                    old.indices.contains(index) && old[index].url == url
                    ? old[index].broken : false
                return Resource(url: url, broken: broken)
            }
        }
    }
}
