import ArgumentParser
import Collections
import Foundation
import VPSDB

struct TutorialCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "tutorial",
        abstract: "tutorial related commands",
        subcommands: [
            LoadTutorialsCommand.self,
        ]
    )
}

enum TutorialError: Error {
    case invalidFormat(String)
    case invalidURL(String)
}

struct TutorialEditArguments: ParsableArguments, Sendable {

    @Option
    var games = URL(fileURLWithPath: "../vps-db/games")

    @Option
    var id: String?

    @Option
    var csv: URL
    
    @Option
    var title: String
    
    @Option
    var author: String
    
    struct CSVFile {
        // lines look like:
        //
        // https://pinballprimer.github.io/alienpoker_G4yen.html,Alien Poker (Williams, SS, 1980)
        
        struct Record {
            let id = UUID()
            let url: URL
            let name: String
            let manufacturer: Manufacturer?
            let year: Int?
            
            init(line: String) throws {
                let pieces = line.components(separatedBy: ",")
                if pieces.count == 5 && pieces[0] == "STD" {
                    if let url = URL(string: pieces[1]) {
                        self.url = url
                    } else {
                        throw TutorialError.invalidURL(pieces[1])
                    }
                    self.name = pieces[2]
                    self.manufacturer = Manufacturer(rawValue: pieces[3])
                    self.year = Int(pieces[4])
                    
                } else if pieces.count > 1 {
                    if let url = URL(string: String(pieces[0])) {
                        self.url = url
                    } else {
                        throw TutorialError.invalidURL(pieces[0])
                    }
                    self.name = String(pieces[1].components(separatedBy: "(")[0].trim())
                    self.year = pieces.compactMap { Int($0.trim()) }.first

                    self.manufacturer = Manufacturer(rawValue: pieces.first { $0.contains("(") }?.split(separator: "(")[1].description ?? "")
                } else {
                    throw TutorialError.invalidFormat(line)
                }
            }
            
            func matches(_ game: Game) -> Bool {
                let name = game.name.replacingOccurrences(of: "The ", with: "").localizedLowercase
                if name.hasPrefix(name.lowercased()) {
                    if let manufacturer {
                        if game.manufacturer != manufacturer {
                            return false
                        }
                    }
                    if let year {
                        if game.year != year {
                            return false
                        }
                    }
                    return true
                } else {
                    return false
                }
            }
            
            var csv: String {
                "STD,\(url),\(name),\(manufacturer?.rawValue ?? ""),\(year?.description ?? "")"
            }
        }
        
        let records: [String:[Record]]
        
        init(url: URL) throws {
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n").map { String($0) }
            
            self.records = try lines
                .filter { !$0.isEmpty }
                .map { try Record(line: $0) }
                .grouped(by: \.name.localizedLowercase)
        }
    }
    
    func loadCSV() throws -> CSVFile {
        try CSVFile(url: self.csv)
    }

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

struct LoadTutorialsCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "load",
        abstract: "load tutorials from CSV"
    )

    @OptionGroup var edit: TutorialEditArguments

    mutating func run() async throws {
        let csv = try edit.loadCSV()
        var addedOrDups = Set<UUID>()
        
        try await edit.visitGames { game in
            var game = game
            
            let name = game.name.replacingOccurrences(of: "The ", with: "").localizedLowercase

            if let records = csv.records[name] {
                for record in records {
                    if record.matches(game) {
                        if game.id == "-1uD97KYfI" {
                            print("XXX")
                            print(game.tutorials.map { $0.url?.description ?? "" }.joined(separator: "\n"))
                        }
                        guard !game.tutorials.contains(where: { $0.url == record.url }) else {
                            addedOrDups.insert(record.id)
                            continue
                        }
                        
                        let gameResource = GameResourceCommon(
                            createdAt: Date(), updatedAt: Date(),
                            game: .init(game: game),
                            urls: [],
                            authors: [.init(name: edit.author)])
                        let tutorial = Tutorial(id: newId(10), gameResource: gameResource, url: record.url, title: edit.title + " " + record.name)
                        game.tutorials.append(tutorial)
                        addedOrDups.insert(record.id)
                    }
                }
            }

            return game
        }
        
        for record in csv.records.values.flatMap({ $0 }) {
            if !addedOrDups.contains(record.id) {
                print(record.csv)
            }
        }
    }
}
