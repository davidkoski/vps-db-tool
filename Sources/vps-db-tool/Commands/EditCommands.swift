import ArgumentParser
import Collections
import Foundation
import VPSDB

struct EditCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "scanning related commands",
        subcommands: [
            EditURLsCommand.self, EditIdsCommand.self, EditTrimCommand.self,
            EditTagFeaturesCommand.self, OneOffCommand.self, UpdateVersionCommand.self,
            UpdateThemeCommand.self, UpdateReThemeCommand.self, UpdateMissingDates.self,
            UpdateGameType.self,
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
        if let youtubeId = item.youtubeId {
            item.youtubeId = youtubeId.trim()
        }
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
                return t
            }

            return game
        }
    }
}

struct UpdateVersionCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "update version"
    )

    @OptionGroup var edit: EditArguments
    @OptionGroup var scan: ScanArguments

    mutating func run() async throws {
        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = scan.site.scanner
        let urls = try await scan.urls(scanner: scanner, client: client)

        var items = [URL: DetailResult]()

        for (variant, url) in urls {
            switch variant {
            case .detail:
                let content = try await client.getString(url)
                let detail = try scanner.scanDetail(url: url, content: content, kind: scan.kind)
                items[Site(url).canonicalize(url)] = detail

            case .list:
                let content = try await client.getString(url)
                let result = try scanner.scanList(url: url, content: content, kind: scan.kind)

                for detail in result.list {
                    let url = detail.url
                    items[Site(url).canonicalize(url)] = detail
                }
            }
        }

        var matched = Set(items.keys)

        try await edit.visitGames { game in
            var game = game

            game.tables = game.tables.map {
                var t = $0
                if let url = t.url {
                    let canonicalURL = Site(url).canonicalize(url)
                    if let item = items[canonicalURL] {
                        matched.remove(canonicalURL)
                        print("#", game.name, item.version ?? "-", t.version ?? "-")
                        if let version = item.version, version != t.version {
                            t.gameResource.version = version
                            if let date = item.date {
                                t.gameResource.createdAt = date
                            }
                        }
                    }
                }
                return t
            }

            return game
        }

        // any that did not match
        for url in matched {
            if let item = items[url] {
                print(url, item.name ?? "")
            }
        }

        print(matched.count)
    }
}

struct UpdateThemeCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "themes",
        abstract: "update themes"
    )

    @OptionGroup var edit: EditArguments

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            if game.theme.contains(.licensedTheme) && game.manufacturer == .original
                && !game.name.hasPrefix("JP")
            {
                game.theme.remove(.licensedTheme)
            }

            return game
        }
    }
}

struct UpdateReThemeCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "retheme",
        abstract: "update retheme"
    )

    @OptionGroup var edit: EditArguments

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            game.tables = game.tables.map {
                var t = $0

                if !t.features.contains(.retheme)
                    && (t.gameResource.comment ?? "").lowercased().contains("retheme")
                {
                    t.features.append(.retheme)
                    t.features.append(.mod)
                }

                if !game.name.hasPrefix("JP") && !t.features.contains(.retheme)
                    && (t.gameResource.comment ?? "").lowercased().contains("based on")
                {
                    t.features.append(.retheme)
                    t.features.append(.mod)
                }

                if !t.features.contains(.retheme)
                    && (t.gameResource.comment ?? "").lowercased().contains("mod of")
                {
                    t.features.append(.retheme)
                    t.features.append(.mod)
                }

                return t
            }

            return game
        }
    }
}

struct UpdateMissingDates: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "missing-dates",
        abstract: "Update missing dates"
    )

    @OptionGroup var edit: EditArguments

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            game.tutorials = game.tutorials.map {
                var t = $0

                if t.createdAt == Date.distantPast {
                    t.gameResource.createdAt = Date()
                }
                if t.updatedAt == Date.distantPast {
                    t.gameResource.updatedAt = Date()
                }

                return t
            }

            return game
        }
    }
}

struct UpdateGameType: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "missing-gametype",
        abstract: "Update missing gametype"
    )

    @OptionGroup var edit: EditArguments

    mutating func run() async throws {
        try await edit.visitGames { game in
            var game = game

            if game.type == nil {
                game.type = .SS
            }

            return game
        }
    }
}
