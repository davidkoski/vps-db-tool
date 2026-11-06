import Foundation
import SwiftUI
import VPSDB
import Logging

private let log = Logger(label: "ROMCheck")

/// Find games that should have rom entries
struct ROMTableCheck: ResourceCheck {
    var id: String { "missingROMs" }
    var name: String { "Missing ROMs" }
    var kinds: Set<GameResourceKind> { [.table] }
    var supportsBulkApply: Bool { true }
    var version = 1

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        guard game.roms.isEmpty else { return [] }
        guard let table = resource as? VPSDB.Table else { return [] }
        
        let db = context.db
        if let parent = table.parent(db), let parentGame = parent.game(db) {
            if !parentGame.roms.isEmpty {
                return ["Copy roms from \(parentGame.name)"]
            }
        }

        return []
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard let table = context.resource(for: item) as? VPSDB.Table else { return nil }
        guard let game = context.game(for: item) else { return nil }
        guard game.roms.isEmpty else { return nil }
        
        let db = context.db
        guard let parent = table.parent(db), let parentGame = parent.game(db) else { return nil }
        guard !parentGame.roms.isEmpty else { return nil }
                
        return .custom(title: "Copy ROMs", apply: {
            try Self.apply(env: $0, game: game, roms: parentGame.roms)
        }) { env in
            CopyROMView(target: game, source: parentGame, message: "Copy from \(parentGame.name)", env: env)
        }
    }
    
    static func apply(env: CustomFixEnvironment, game: Game, roms: [ROM]) throws {
        try env.update(game.id) { game in
            game.roms = roms.map {
                var new = $0
                
                new.id = newId()
                new.gameResource.game = .init(game: game)
                
                return new
            }
        }
    }

    struct CopyROMView: View {
        
        let target: Game
        let source: Game
        
        let message: String

        let env: CustomFixEnvironment
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("\(target.name) (\(target.manufacturer.rawValue) \((target.year ?? 0).description))")
                Text(message)
                
                Button("Apply", action: apply)
                
                Spacer()
            }
            .padding()
        }
        
        func apply() {
            do {
                try ROMTableCheck.apply(env: env, game: target, roms: source.roms)
                env.done(true)
            } catch {
                log.error("Unable to update: \(error)")
                env.done(false)
            }
        }
    }
}

/// All Games should have the same set of ROMs
struct SynchronizeROMSCheck: ResourceCheck {
    var id: String { "synchronizeROMS" }
    var name: String { "Synchronize ROMs" }
    var kinds: Set<GameResourceKind> { [.table] }
    var supportsBulkApply: Bool { true }
    var version = 1

    func gatherROMs(db: Database, versions: Set<String>) -> [ROM] {
        var versions = versions
        
        // first gather the transitive closure of versions
        for rom in db.roms.all {
            if let version = rom.version, versions.contains(version) {
                if let game = rom.game(db) {
                    versions.formUnion(game.roms.compactMap { $0.version })
                }
            }
        }
        
        // now gather all the unique urls with those versions
        var result = [ROM]()
        var seen = Set<URL>()
        
        for rom in db.roms.all {
            // some roms don't have a url so map all those to one
            if let version = rom.version, versions.contains(version) {
                let url = rom.url ?? URL(string: "https://vpuniverse.com")!
                let canonical = Site(url).canonicalize(url)
                if !seen.contains(canonical) {
                    result.append(rom)
                    seen.insert(canonical)
                }
            }
        }
        
        return result
    }

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        // we can only gather roms if we already have roms
        guard !game.roms.isEmpty else { return [] }
        
        // once per game, but we don't iterate games, we iterate tables
        if game.tables.first?.id != resource.id {
            return []
        }
        
        let roms = gatherROMs(db: context.db, versions: game.roms.compactMap { $0.version }.set())
        if roms.count != game.roms.count {
            let name = roms.compactMap { $0.version }.sorted().first ?? "missing"
            return ["Gather roms \(game.roms.count) -> \(roms.count) (\(name))"]
        }
        
        return []
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard let game = context.game(for: item) else { return nil }
        guard !game.roms.isEmpty else { return nil }

        let roms = gatherROMs(db: context.db, versions: game.roms.compactMap { $0.version }.set())

        return .custom(title: "Gather ROMs", apply: { env in
            try Self.apply(env: env, game: game, roms: roms)
        }) { env in
            CopyROMView(target: game, roms: roms, env: env)
        }
    }
    
    static func apply(env: CustomFixEnvironment, game: Game, roms: [ROM]) throws {
        try env.update(game.id) { game in
            game.roms = roms.map {
                var new = $0
                
                new.id = newId()
                new.gameResource.game = .init(game: game)
                
                return new
            }
        }
    }
    
    struct CopyROMView: View {
        
        let target: Game
        let roms: [ROM]
        
        let env: CustomFixEnvironment
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("\(target.name) (\(target.manufacturer.rawValue) \((target.year ?? 0).description))")

                ForEach(roms, id: \.id) { rom in
                    HStack {
                        Text("rom: \(rom.version ?? "missing")")
                        if let url = rom.url {
                            Text(" url: ")
                            Link(destination: url) { Text(url.host() ?? "unknown") }
                        }
                        if let author = rom.gameResource.authors.first {
                            Text(" author: \(author.name)")
                        }
                    }
                    .bold(target.roms.contains { $0.version == rom.version })
                }
                
                Button("Apply", action: apply)
                
                Spacer()
            }
            .padding()
        }
        
        func apply() {
            Task {
                do {
                    try SynchronizeROMSCheck.apply(env: env, game: target, roms: roms)
                    env.done(true)
                } catch {
                    log.error("Unable to update: \(error)")
                    env.done(false)
                }
            }
        }
    }
}
