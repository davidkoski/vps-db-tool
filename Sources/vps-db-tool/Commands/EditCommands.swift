import ArgumentParser
import Collections
import Foundation

struct EditCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "scanning related commands",
        subcommands: [
            EditURLsCommand.self, EditIdsCommand.self, EditTrimCommand.self,
            EditTagFeaturesCommand.self, OneOffCommand.self,
        ]
    )
}

enum EditError: Error {
    case editError(URL, Error)
}

struct EditArguments: ParsableArguments, Sendable {

    @Option
    var games = URL(fileURLWithPath: "../vps-db/games")

    @Option
    var id: String?

    func gameFiles() throws -> [URL] {
        if let id {
            [games.appending(component: id).appendingPathExtension("json")]
        } else {
            try FileManager.default.contentsOfDirectory(at: games, includingPropertiesForKeys: [])
        }
    }

    func visitGames(_ visitor: (Game) async throws -> Game) async throws {
        for url in try gameFiles() {
            do {
                print(url.lastPathComponent)
                let game = try JSONDecoder().decode(Game.self, from: Data(contentsOf: url))

                let new = try await visitor(game)
                if new != game {
                    print("UPDATE: \(url.lastPathComponent)")
                    try JSONEncoder().encode(new).write(to: url, options: .atomic)
                }

            } catch {
                throw EditError.editError(url, error)
            }
        }
    }
}

struct EditURLsCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "urls",
        abstract: "edit (normalize) urls"
    )

    @OptionGroup var edit: EditArguments

    func update<T: GameResource>(_ item: T) -> T {
        var item = item

        item.gameResource.urls = item.gameResource.urls
            .map {
                var resource = $0
                resource.url = Site(resource.url).normalize(resource.url)
                return resource
            }

        return item
    }

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            game.tables = game.tables.map { update($0) }
            game.backglasses = game.backglasses.map { update($0) }
            game.tutorials = game.tutorials.map { update($0) }
            game.roms = game.roms.map { update($0) }
            game.pupPacks = game.pupPacks.map { update($0) }
            game.altColors = game.altColors.map { update($0) }
            game.altSounds = game.altSounds.map { update($0) }
            game.sounds = game.sounds.map { update($0) }
            game.povs = game.povs.map { update($0) }
            game.wheels = game.wheels.map { update($0) }
            game.toppers = game.toppers.map { update($0) }
            game.mediaPacks = game.mediaPacks.map { update($0) }
            game.rules = game.rules.map { update($0) }

            return game
        }
    }
}

struct EditIdsCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "ids",
        abstract: "make sure ids are set"
    )

    @OptionGroup var edit: EditArguments

    func update<T: GameResource>(game: Game, _ item: T) -> T {
        var item = item
        item.gameResource.game = .init(game: game)
        return item
    }

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            game.tables = game.tables.map { update(game: game, $0) }
            game.backglasses = game.backglasses.map { update(game: game, $0) }
            game.tutorials = game.tutorials.map { update(game: game, $0) }
            game.roms = game.roms.map { update(game: game, $0) }
            game.pupPacks = game.pupPacks.map { update(game: game, $0) }
            game.altColors = game.altColors.map { update(game: game, $0) }
            game.altSounds = game.altSounds.map { update(game: game, $0) }
            game.sounds = game.sounds.map { update(game: game, $0) }
            game.povs = game.povs.map { update(game: game, $0) }
            game.wheels = game.wheels.map { update(game: game, $0) }
            game.toppers = game.toppers.map { update(game: game, $0) }
            game.mediaPacks = game.mediaPacks.map { update(game: game, $0) }
            game.rules = game.rules.map { update(game: game, $0) }

            return game
        }
    }
}

struct EditTrimCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "trim",
        abstract: "trim strings"
    )

    @OptionGroup var edit: EditArguments

    func update<T: GameResource>(_ item: T) -> T {
        var item = item
        item.gameResource.comment = item.gameResource.comment?.trim()
        item.gameResource.version = item.gameResource.version?.trim()
        item.gameResource.authors = item.gameResource.authors
            .map {
                Author(name: $0.name.trim())
            }
        return item
    }

    func updateTable(_ item: Table) -> Table {
        var item = item
        item.edition = item.edition?.trim()
        item.gameFileName = item.gameFileName?.trim()
        return item
    }

    func updateTutorial(_ item: Tutorial) -> Tutorial {
        var item = item
        item.youtubeId = item.youtubeId.trim()
        item.title = item.title.trim()
        return item
    }

    func updateAltColors(_ item: AltColors) -> AltColors {
        var item = item
        item.fileName = item.fileName?.trim()
        item.folder = item.folder?.trim()
        item.type = item.type?.trim()
        return item
    }

    func updateGame(_ item: Game) -> Game {
        var item = item
        item.name = item.name.trim()
        item.mpu = item.mpu?.trim()
        item.designers = OrderedSet(item.designers.map { $0.trim() })
        return item
    }

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = updateGame(game)

            game.tables = game.tables.map { update($0) }
            game.tables = game.tables.map { updateTable($0) }
            game.backglasses = game.backglasses.map { update($0) }
            game.tutorials = game.tutorials.map { update($0) }
            game.tutorials = game.tutorials.map { updateTutorial($0) }
            game.roms = game.roms.map { update($0) }
            game.pupPacks = game.pupPacks.map { update($0) }
            game.altColors = game.altColors.map { update($0) }
            game.altColors = game.altColors.map { updateAltColors($0) }
            game.altSounds = game.altSounds.map { update($0) }
            game.sounds = game.sounds.map { update($0) }
            game.povs = game.povs.map { update($0) }
            game.wheels = game.wheels.map { update($0) }
            game.toppers = game.toppers.map { update($0) }
            game.mediaPacks = game.mediaPacks.map { update($0) }
            game.rules = game.rules.map { update($0) }

            return game
        }
    }
}

struct EditTagFeaturesCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "tag-feature",
        abstract: "remove tableFormat from features"
    )

    @OptionGroup var edit: EditArguments

    @Option(parsing: .upToNextOption)
    var ids: [String]

    @Option
    var feature: TableFeature

    mutating func run() async throws {
        let ids = try Set(
            ids
                .flatMap {
                    if $0.hasPrefix("/") {
                        try String(contentsOf: URL(fileURLWithPath: $0), encoding: .utf8)
                            .split(separator: "\n")
                            .map { String($0) }
                    } else {
                        [$0]
                    }
                })

        try await edit.visitGames { game in
            var game = game
            game.tables = game.tables.map {
                var t = $0
                if ids.contains(t.id) {
                    if !t.features.contains(feature) {
                        t.features.append(feature)
                    }
                }
                return t
            }
            return game
        }
    }
}

struct OneOffCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "one-off",
        abstract: "random one-off command"
    )

    @OptionGroup var edit: EditArguments

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            game.tables = game.tables.map {
                var t = $0
                if t.features.contains(.oldPatch) {
                    t.features.remove(.oldPatch)
                    t.features.append(.patch)
                }
                return t
            }

            return game
        }
    }
}
