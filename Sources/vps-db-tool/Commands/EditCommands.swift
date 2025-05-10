import ArgumentParser
import Foundation

struct EditCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "scanning related commands",
        subcommands: [
            EditURLsCommand.self, EditIdsCommand.self,
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
