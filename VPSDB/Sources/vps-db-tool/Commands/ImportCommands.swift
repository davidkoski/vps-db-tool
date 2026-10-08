import ArgumentParser
import Foundation
import VPSDB

#if canImport(TabularData)

import TabularData

struct ImportCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "import related commands",
        subcommands: [
            AugmentCommand.self,
            ImportRuleCommand.self, ImportWheelArtCommand.self,
        ]
    )
}

struct ImportArguments: ParsableArguments, Sendable {
    @Option var csv: URL
    @Option var separator = "\t"
    
    var data: DataFrame {
        get throws {
            let options = CSVReadingOptions(delimiter: separator.first!)
            return try DataFrame(contentsOfCSVFile: csv, options: options)
        }
    }
}

struct AugmentCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "augment",
        abstract: "resolve table names"
    )

    @OptionGroup var db: VPSDbArguments
    
    @Option var csv: URL
    @Option var column = 0
    @Option var separator = "\t"

    mutating func run() async throws {
        let db = try await db.database()
        
        let lines = csv.lines
        for try await line in lines {
            let columns = line.split(separator: separator)
            let column = columns[column]
            
            // Theatre of Magic (Bally 1995)
            let front = column.split(separator: "(")[0].split(separator: "-")[0]
            let name = String(front.trimmingCharacters(in: .whitespaces))
            var printed = false
            if let games = db.gamesByName[name] {
                if games.count == 1 {
                    print(line + separator + games[0].id)
                    printed = true
                }
            }
            
            if !printed {
                print(line)
            }
        }
    }
}

struct ImportRuleCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "import rules"
    )

    @OptionGroup var edit: EditArguments
    @OptionGroup var importData: ImportArguments

    mutating func run() async throws {
        
        let data = try importData.data
        
        let idCol = ColumnID("id", String.self)
        let rows = Dictionary(grouping: data.rows) { row in
            row[idCol] ?? "none"
        }
        
        let authorCol = ColumnID("author", String.self)
        let versionCol = ColumnID("version", Double.self)
        let urlCol = ColumnID("url", String.self)
        let commentCol = ColumnID("comment", String.self)
        let dateCol = ColumnID("date", Double.self)

        try await edit.visitGames { game in
            var game = game
            
            if let updates = rows[game.id] {
                for row in updates {
                    let date = Date(timeIntervalSince1970: row[dateCol]!)
                    let gameResource = GameResourceCommon(
                        createdAt: date, updatedAt: Date(),
                        comment: row[commentCol],
                        game: .init(game: game),
                        urls: [.init(url: URL(string: row[urlCol]!)!, broken: false)],
                        authors: [.init(name: row[authorCol]!)],
                        version: "1.0.0"
                    )
                    let rule = Rules(id: newId(10), gameResource: gameResource)
                    game.rules.append(rule)
                }
            }

            return game
        }
    }

}

struct ImportWheelArtCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "wheels",
        abstract: "import wheel art"
    )

    @OptionGroup var edit: EditArguments
    @OptionGroup var importData: ImportArguments

    mutating func run() async throws {
        
        let data = try importData.data
        
        let idCol = ColumnID("id", String.self)
        let rows = Dictionary(grouping: data.rows) { row in
            row[idCol] ?? "none"
        }
        
        let authorCol = ColumnID("author", String.self)
        let versionCol = ColumnID("version", Double.self)
        let urlCol = ColumnID("url", String.self)
        let commentCol = ColumnID("comment", String.self)
        let dateCol = ColumnID("date", Double.self)

        try await edit.visitGames { game in
            var game = game
            
            if let updates = rows[game.id] {
                for row in updates {
                    let date = Date(timeIntervalSince1970: row[dateCol]!)
                    let gameResource = GameResourceCommon(
                        createdAt: date, updatedAt: Date(),
                        comment: row[commentCol],
                        game: .init(game: game),
                        urls: [.init(url: URL(string: row[urlCol]!)!, broken: false)],
                        authors: [.init(name: row[authorCol]!)],
                        version: "1.0.0"
                    )
                    let item = WheelArt(id: newId(10), gameResource: gameResource)
                    game.wheels.append(item)
                }
            }

            return game
        }
    }

}

#else

struct ImportCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "import related commands",
        subcommands: [
        ]
    )
}

#endif
