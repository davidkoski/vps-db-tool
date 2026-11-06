import Foundation
import SwiftUI
import VPSDB

// MARK: - Missing fields

/// Resources with no authors, version or created date -- the fix scans the
/// resource's page(s) and fills in the missing fields.
struct DuplicateURLCheck: ResourceCheck {
    var id: String { "duplicateURL" }
    var name: String { "Duplicate URL" }
    var kinds: Set<GameResourceKind> { [.table, .b2s] }
    var supportsBulkApply: Bool { true }
    var version = 1

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        let common = resource.gameResource
        var problems = [String]()
        if common.urls.count != Set(common.urls.map { $0.url }).count {
            problems.append("Duplicate URL")
        }
        return problems
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard var resource = context.resource(for: item) else { return nil }

        var removed = [String]()
        var seen = Set<Resource>()
        let current = resource.gameResource.urls
        resource.gameResource.urls = []
        for item in current {
            if !seen.contains(item) {
                resource.gameResource.urls.append(item)
                seen.insert(item)
            } else {
                removed.append(item.url.host() ?? item.url.description)
            }
        }

        if removed.isEmpty {
            return nil
        }

        return FixProposal(
            resource: resource, detail: nil,
            changes: [
                .init(field: .urls, old: "", new: "Removed \(removed.joined(separator: ", "))")
            ])
    }
}
