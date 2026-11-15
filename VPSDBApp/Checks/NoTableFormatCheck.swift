import Foundation
import SwiftUI
import VPSDB

struct NoTableFormatCheck: ResourceCheck {
    var id: String { "noTableFormat" }
    var name: String { "No Table Format" }
    var kinds: Set<GameResourceKind> { [.table] }
    var version = 1

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        if let table = resource as? VPSDB.Table {
            if table.tableFormat == nil {
                return ["Missing Table Format"]
            }
        }
        return []
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard let table = context.resource(for: item) as? VPSDB.Table else { return nil }

        if table.tableFormat == nil {
            return FixProposal(
                resource: table, detail: nil,
                changes: [
                    .init(field: .urls, old: "", new: "Set format")
                ])
        }

        return nil
    }
}
