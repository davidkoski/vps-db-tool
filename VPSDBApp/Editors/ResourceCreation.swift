import Foundation
import Logging
import VPSDB

private let log = Logger(label: "ResourceCreation")

/// Create / save resources without a view -- shared by ``ResourceEditor`` and
/// bulk approve on the updates view.
enum ResourceCreation {

    /// Fetch the full detail page and build a new resource from it.
    static func create<Resource: EditableGameResource>(
        _ type: Resource.Type = Resource.self,
        detail: DetailResult, game: Game, db: Database, client: HTTPClient
    ) async throws -> (resource: Resource, fullDetail: DetailResult) {
        let fullDetail = try await detail.detailRequest.fetch(client: client, scanCache: scanCache)
        return (Resource(detail: fullDetail, game: game, db: db), fullDetail)
    }

    /// Add (or replace) the resource on its game and write the game.
    static func save<Resource: EditableGameResource>(
        _ resource: Resource, game: Game, db: inout Database
    ) throws {
        log.info("save \(Resource.kind) \(resource.id) for \(game.id)")
        try db.update(game) { game in
            game.upsert(resource, at: Resource.gameKeyPath)
        }
    }

    /// Save the resource for each game: the first game gets the resource as is,
    /// the others a copy with a new id -- each with its own ``GameRef``.
    static func save<Resource: EditableGameResource>(
        _ resource: Resource, games: [Game], db: inout Database
    ) throws {
        for (index, game) in games.enumerated() {
            var copy = resource
            if index > 0 {
                // ids are unique across the db
                copy.id = newId()
            }
            copy.gameResource.game = GameRef(game: game)
            try save(copy, game: game, db: &db)
        }
    }

    /// Instead of saving a new resource, add its urls to an existing one
    /// (the same release on another site) and save that.
    static func merge<Resource: EditableGameResource>(
        _ resource: Resource, into other: Resource, game: Game, db: inout Database
    ) throws -> MergeURLAction? {
        var other = other
        let result = other.mergeURL(other: resource)

        log.info("merge \(Resource.kind) \(resource.url?.absoluteString ?? "") into \(other.id)")
        try save(other, game: game, db: &db)
        return result
    }
}
