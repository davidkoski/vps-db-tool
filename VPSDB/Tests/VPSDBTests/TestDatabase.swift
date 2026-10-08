import Foundation
@testable import VPSDB

let flashGordon = Game(
    id: "18iwweY9",
    createdAt: Date(), updatedAt: Date(), lastCreatedAt: Date(),
    name: "Flash Gordon", manufacturer: .bally,
    imageUrl: nil, mpu: nil, year: 1981,
    theme: [.fictionalCharacters, .scienceFiction],
    designers: ["Claude Fernandez"],
    type: .SS, players: 4,
    ipdbUrl: nil, imgUrl: nil, tables: [], backglasses: [],
    tutorials: [], roms: [], pupPacks: [], altColors: [],
    altSounds: [], povs: [], wheels: [], toppers: [],
    mediaPacks: [], rules: [], sounds: [],
    broken: false, urls: [])

let flash = Game(
    id: "-y7tj2TZ",
    createdAt: Date(), updatedAt: Date(), lastCreatedAt: Date(),
    name: "Flash", manufacturer: .williams,
    imageUrl: nil, mpu: nil, year: 1979,
    theme: [.fantasy],
    designers: ["Steve Ritchie"],
    type: .SS, players: 4,
    ipdbUrl: nil, imgUrl: nil, tables: [], backglasses: [],
    tutorials: [], roms: [], pupPacks: [], altColors: [],
    altSounds: [], povs: [], wheels: [], toppers: [],
    mediaPacks: [], rules: [], sounds: [],
    broken: false, urls: [])

let starTrek1 = Game(
    id: "423FZHZj",
    createdAt: Date(), updatedAt: Date(), lastCreatedAt: Date(),
    name: "Star Trek", manufacturer: .gottlieb,
    imageUrl: nil, mpu: nil, year: 1971,
    theme: [.fantasy],
    designers: ["Steve Ritchie"],
    type: .EM, players: 1,
    ipdbUrl: nil, imgUrl: nil, tables: [], backglasses: [],
    tutorials: [], roms: [], pupPacks: [], altColors: [],
    altSounds: [], povs: [], wheels: [], toppers: [],
    mediaPacks: [], rules: [], sounds: [],
    broken: false, urls: [])

let starTrek2 = Game(
    id: "6ZU8msq0",
    createdAt: Date(), updatedAt: Date(), lastCreatedAt: Date(),
    name: "Star Trek", manufacturer: .bally,
    imageUrl: nil, mpu: nil, year: 1979,
    theme: [.spaceFantasy, .outerSpace],
    designers: ["Gary Gayton"],
    type: .SS, players: 4,
    ipdbUrl: nil, imgUrl: nil, tables: [], backglasses: [],
    tutorials: [], roms: [], pupPacks: [], altColors: [],
    altSounds: [], povs: [], wheels: [], toppers: [],
    mediaPacks: [], rules: [], sounds: [],
    broken: false, urls: [])

let starTrek3 = Game(
    id: "P12wTlyY",
    createdAt: Date(), updatedAt: Date(), lastCreatedAt: Date(),
    name: "Star Trek", manufacturer: .dataEast,
    imageUrl: nil, mpu: nil, year: 1991,
    theme: [.spaceFantasy, .outerSpace],
    designers: ["Joe Kaminkow", "Ed Cebula"],
    type: .SS, players: 4,
    ipdbUrl: nil, imgUrl: nil, tables: [], backglasses: [],
    tutorials: [], roms: [], pupPacks: [], altColors: [],
    altSounds: [], povs: [], wheels: [], toppers: [],
    mediaPacks: [], rules: [], sounds: [],
    broken: false, urls: [])

let testDatabase = Database(
    url: nil,
    games: [
        flashGordon.id: flashGordon,
        flash.id: flash,
        starTrek1.id: starTrek1,
        starTrek2.id: starTrek2,
        starTrek3.id: starTrek3,
    ]
)
