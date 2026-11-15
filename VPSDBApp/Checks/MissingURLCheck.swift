import Foundation
import SwiftUI
import VPSDB

struct MissingURLCheck: ResourceCheck {
    var id: String { "missingURL" }
    var name: String { "Missing URL" }
    var kinds: Set<GameResourceKind> { Set(GameResourceKind.allCases) }
    var version = 1

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        let common = resource.gameResource
        var problems = [String]()
        if common.urls.isEmpty {
            problems.append("No URL")
        }
        return problems
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard let resource = context.resource(for: item) else { return nil }
        guard let game = context.game(for: item) else { return nil }

        if resource.kind == .b2s {
            // these often go with the table
            if let resourceFirstAuthor = resource.gameResource.authors.first {
                let tables = game.tables.filter {
                    $0.gameResource.authors.first == resourceFirstAuthor
                }

                if tables.count == 1 {
                    return propose(resource, from: tables[0])
                }

                if tables.count > 1 {
                    return proposeManual(resource)
                } else {
                    return proposeManual(resource)
                }
            } else {
                // no author, but if it is a single table we can use that
                if game.tables.count == 1 {
                    return propose(resource, from: game.tables[0])
                }

                return proposeManual(resource)
            }
        }
        return proposeManual(resource)
    }

    private func propose<R: GameResource>(_ resource: R, from table: VPSDB.Table)
        -> FixProposal
    {
        var new = resource
        var changes = [ProposedChange]()

        new.gameResource.urls = table.gameResource.urls
        for url in new.gameResource.urls {
            changes.append(.init(field: .urls, old: "empty", new: url.url.description))
        }

        return FixProposal(resource: new, detail: nil, changes: changes)
    }

    private func proposeManual<R: GameResource>(_ resource: R)
        -> FixProposal
    {
        return FixProposal(
            resource: resource, detail: nil,
            changes: [
                .init(field: .urls, old: "empty", new: "manual")
            ])
    }

}
