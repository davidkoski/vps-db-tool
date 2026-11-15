import Foundation
internal import OrderedCollections
import SwiftUI
import VPSDB

private let commentPattern: [ScanPattern<MissingModCheck.Disposition>] = [
    .init(/retheme of/.ignoresCase(), .commentRetheme),
    .init(/reskin of/.ignoresCase(), .commentRetheme),
    .init(/mod of/.ignoresCase(), .commentMod),
]

struct MissingModCheck: ResourceCheck {
    var id: String { "missingMod" }
    var name: String { "Missing Mod" }
    var kinds: Set<GameResourceKind> { [.table] }
    var supportsBulkApply: Bool { true }
    var version = 1

    enum Disposition {
        case noAction
        case addMod
        case addRetheme
        case commentRetheme
        case commentMod
        case probablyMod
        case probablyRetheme
        case probablyParent
        case brokenParent
    }

    func determineFix(table: VPSDB.Table, game: Game, context: CheckContext) -> Disposition {
        var targetFeature: TableFeature
        var sure: Bool

        if table.isRoot {
            return .noAction
        }

        if table.parentId != nil {
            // has parent -- mod or retheme
            if let parentTable = table.parent(context.db),
                let parentGame = parentTable.game(context.db)
            {
                if parentGame.id != game.id {
                    // different game, should be a retheme
                    targetFeature = .retheme
                    sure = true
                } else {
                    targetFeature = .mod
                    sure = true
                }
            } else {
                // can't figure out the parent
                return .brokenParent
            }
        } else {

            let commentFeatures = scanText([table.gameResource.comment], commentPattern)
            if let first = commentFeatures.first {
                return first
            }

            // no parent, if it has many authors it _might_ be a mod
            sure = false
            if table.gameResource.authors.count > 1 {
                if game.tables.count == 1 {
                    targetFeature = .retheme
                } else {
                    targetFeature = .mod
                }
            } else {
                return .noAction
            }
        }

        if table.features.contains(targetFeature) {
            return sure ? .noAction : .probablyParent
        } else {
            if targetFeature == .mod {
                return sure ? .addMod : .probablyMod
            } else {
                return sure ? .addRetheme : .probablyRetheme
            }
        }
    }

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        guard let table = resource as? VPSDB.Table else { return [] }

        switch determineFix(table: table, game: game, context: context) {
        case .noAction: return []
        case .addMod: return ["Add Mod"]
        case .addRetheme: return ["Add Retheme"]
        case .commentMod: return ["Comment Mod"]
        case .commentRetheme: return ["Comment Retheme"]
        case .probablyMod: return ["Probably Mod"]
        case .probablyRetheme: return ["Probably Retheme"]
        case .probablyParent: return ["Probably Parent"]
        case .brokenParent: return ["Broken Parent"]
        }
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard let table = context.resource(for: item) as? VPSDB.Table else { return nil }
        guard let game = context.game(for: item) else { return nil }

        func df(_ table: VPSDB.Table) -> String {
            table.features.map { $0.rawValue }.joined(separator: ", ")
        }

        switch determineFix(table: table, game: game, context: context) {
        case .noAction: return nil
        case .addMod:
            var new = table
            new.features.remove(.retheme)
            new.features.append(.mod)
            return .init(
                resource: new, detail: nil,
                changes: [
                    .init(field: .features, old: df(table), new: df(new))
                ])
        case .addRetheme:
            var new = table
            new.features.remove(.mod)
            new.features.append(.retheme)
            return .init(
                resource: new, detail: nil,
                changes: [
                    .init(field: .features, old: df(table), new: df(new))
                ])

        case .commentMod, .commentRetheme:
            return .init(resource: table, detail: nil, changes: [])

        case .probablyMod:
            return .init(resource: table, detail: nil, changes: [])

        case .probablyRetheme:
            return .init(resource: table, detail: nil, changes: [])

        case .probablyParent:
            return .init(resource: table, detail: nil, changes: [])

        case .brokenParent:
            return .init(resource: table, detail: nil, changes: [])

        }
    }
}
