import SwiftUI
import VPSDB

/// An existing resource that a save replaces -- e.g. a rule being converted
/// to a tutorial: the new resource (same id, other kind) is added and this
/// one removed from the game in the same write.
struct ResourceReplacement: Hashable, Sendable {
    let kind: GameResourceKind
    let id: String
}

extension EnvironmentValues {
    /// Set when the editor is converting an existing resource to another kind
    /// -- ``ResourceEditor`` removes the original when it saves.
    @Entry var replacingResource: ResourceReplacement? = nil
}

extension EditableGameResource {
    /// Rebuild an existing resource (of any kind) as this kind, keeping its id
    /// and common fields (dates, authors, comment, urls, version).
    ///
    /// Kind-specific fields get the defaults a new resource would get.
    /// Tutorials store their url differently -- in `youtubeId` / `url`
    /// rather than the common urls -- so those are moved across.
    static func converted(from source: any GameResource, game: Game, db: Database) -> Self {
        let sourceURLs = commonURLs(of: source)
        let title = (source as? Tutorial)?.title

        let detail = DetailResult(
            .detail,
            url: sourceURLs.first?.url ?? URL(string: "https://example.com")!,
            kind: kind, name: title ?? game.name)

        var resource = Self(detail: detail, game: game, db: db)
        resource.id = source.id

        var common = source.gameResource
        common.game = GameRef(game: game)
        common.urls = sourceURLs
        if !hasVersion {
            common.version = nil
        }
        if let title, !title.isEmpty, (common.comment ?? "").isEmpty {
            // tutorial -> other: keep the title as the comment
            common.comment = title
        }

        if var tutorial = resource as? Tutorial {
            // stored in youtubeId / url, not the common urls
            let url = sourceURLs.first?.url
            let youtubeId = url.flatMap(youtubeVideoId)
            tutorial.youtubeId = youtubeId
            tutorial.url = youtubeId == nil ? url : nil
            tutorial.title = common.comment ?? game.name
            common.urls = []
            tutorial.gameResource = common
            return tutorial as! Self
        }

        resource.gameResource = common
        return resource
    }
}

/// The urls of a resource in the common form -- tutorials keep theirs in
/// `youtubeId` / `url`.
private func commonURLs(of resource: any GameResource) -> [VPSDB.Resource] {
    guard let tutorial = resource as? Tutorial else {
        return resource.gameResource.urls
    }
    let url =
        tutorial.youtubeId.flatMap { URL(string: "https://www.youtube.com/watch?v=\($0)") }
        ?? tutorial.url
    return [url].compactMap { $0 }.map { VPSDB.Resource(url: $0, broken: false) }
}

/// Convert `resource` to `kind` -- `nil` if the kind has no editor.
func convertResource(
    _ resource: any GameResource, to kind: GameResourceKind, game: Game, db: Database
) -> (any GameResource)? {
    editableType(for: kind)?.converted(from: resource, game: game, db: db)
}

extension Game {
    /// Remove the resource of `kind` with `id` from the game.
    mutating func removeResource(kind: GameResourceKind, id: String) {
        switch kind {
        case .game: break
        case .table: tables.removeAll { $0.id == id }
        case .b2s: backglasses.removeAll { $0.id == id }
        case .tutorial: tutorials.removeAll { $0.id == id }
        case .rom: roms.removeAll { $0.id == id }
        case .pupPack: pupPacks.removeAll { $0.id == id }
        case .altColor: altColors.removeAll { $0.id == id }
        case .altSound: altSounds.removeAll { $0.id == id }
        case .sound: sounds.removeAll { $0.id == id }
        case .pov: povs.removeAll { $0.id == id }
        case .wheelArt: wheels.removeAll { $0.id == id }
        case .topper: toppers.removeAll { $0.id == id }
        case .mediaPack: mediaPacks.removeAll { $0.id == id }
        case .rule: rules.removeAll { $0.id == id }
        }
    }
}
