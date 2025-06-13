import Foundation

public enum Manufacturer: String, Codable, Sendable, Equatable {

    case aPirmischer = "A. Pirmischer"
    case abt = "A.B.T."
    case abbey = "Abbey"
    case alvinG = "Alvin G."
    case appleTime = "Apple Time"
    case arkon = "Arkon"
    case astroGames = "Astro Games"
    case atari = "Atari"
    case automatic = "Automatic"
    case automaticos = "Automaticos"
    case bally = "Bally"
    case barok = "Barok Co"
    case belgamko = "Belgamko"
    case bell = "Bell Games"
    case benchmark = "Benchmark Games"
    case billPort = "Bill Port"
    case brunswick = "Brunswick"
    case cicPlay = "CIC Play"
    case capcom = "Capcom"
    case chicagoCoin = "Chicago Coin"
    case cirsa = "Cirsa"
    case codemasters = "Codemasters"
    case culik = "Culik Pinball"
    case cunningDevelopments = "Cunning Developments"
    case dataEast = "Data East"
    case daval = "Daval"
    case digitalIllusions = "Digital Illusions"
    case dozingCatSoftware = "Dozing Cat Software"
    case durham = "Durham"
    case electromatic = "Electromatic"
    case emagar = "Emagar"
    case exhibit = "Exhibit"
    case fabulousFantasies = "Fabulous Fantasies"
    case fipermatic = "Fipermatic"
    case gamePlan = "Game Plan"
    case geiger = "Geiger"
    case genco = "Genco"
    case gottlieb = "Gottlieb"
    case grandProducts = "Grand Products"
    case hankin = "Hankin"
    case hiSkor = "Hi-Skor"
    case hutchison = "Hutchison"
    case idsa = "IDSA"
    case inOutdoor = "In & Outdoor"
    case inder = "Inder"
    case interflip = "Interflip"
    case internationalConcepts = "International Concepts"
    case jEsteban = "J. Esteban"
    case jFLinck = "J.F. Linck"
    case jpSeeburg = "J.P. Seeburg"
    case jennings = "Jennings"
    case jocmatic = "Jocmatic"
    case joctronic = "Joctronic"
    case juegosPopulares = "Juegos Populares"
    case keeney = "Keeney"
    case komaya = "Komaya"
    case ltdBrasil = "LTD do Brasil"
    case mac = "MAC"
    case marbleGames = "Marble Games"
    case maresa = "Maresa"
    case maxis = "Maxis"
    case microsoft = "Microsoft"
    case midway = "Midway"
    case mills = "Mills Novelty Company"
    case nsm = "NSM"
    case nintendo = "Nintendo"
    case nuovaBellGames = "Nuova Bell Games"
    case original = "Original"
    case pamco = "PAMCO"
    case pace = "Pace"
    case peo = "Peo"
    case petaco = "Petaco"
    case peyper = "Peyper"
    case pierce = "Pierce"
    case pinballDreams = "Pinball Dreams"
    case pinstar = "Pinstar"
    case pinventions = "Pinventions"
    case playmatic = "Playmatic"
    case professionalPinball = "Professional Pinball"
    case quezalPinball = "Quetzal Pinball"
    case rally = "Rally"
    case recel = "Recel"
    case recreativosFranco = "Recreativos Franco"
    case rockOla = "Rock-ola"
    case rowamet = "Rowamet"
    case sega = "Sega"
    case segasa = "Segasa"
    case sleic = "Sleic"
    case sonic = "Sonic"
    case spinball = "Spinball S.A.L."
    case spooky = "Spooky Pinball"
    case sportmatic = "Sport matic"
    case staal = "Staal"
    case stern = "Stern"
    case stoner = "Stoner"
    case taito = "Taito"
    case taitoBrasil = "Taito do Brasil"
    case tecnoplay = "Tecnoplay"
    case tekhan = "Tekhan"
    case tiltMovie = "Tilt Movie"
    case unidesa = "Unidesa"
    case united = "United"
    case videoDens = "Video Dens"
    case walterSteiner = "Walter Steiner"
    case whizbang = "WhizBang Pinball"
    case wico = "Wico"
    case williams = "Williams"
    case zaccaria = "Zaccaria"
    case zen = "Zen Studios"
    case missing = ""
    case unknown = "unknown"

    var shouldHaveIPDBEntry: Bool {
        switch self {
        case .zen, .original: false
        default: true
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let c = Manufacturer(string: value) {
            self = c
        } else {
            throw ManufacturerError.unknownManufacturer(value)
        }
    }

    init?(string value: String) {
        if let c = Manufacturer(rawValue: value) {
            self = c
        } else if let c = map[value] {
            self = c
        } else {
            return nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

enum ManufacturerError: Error {
    case unknownManufacturer(String)
}

private let map: [String: Manufacturer] = [
    "A.B.T. Manufacturing Company": .abt,
    "Alvin G. and Company": .alvinG,
    "Arkon Automaten, GmbH": .arkon,
    "Astro Games Incorporated": .astroGames,
    "Atari, Incorporated": .atari,
    "Talleres del Llobregat S.A. [Automaticos]": .automaticos,
    "Automaticos MonteCarlo": .automaticos,
    "Automaticos C.M.C.": .automaticos,
    "Automatic Industries, Incorporated": .automatic,
    "Automatic Industries, Ltd.": .automatic,
    "Bally Manufacturing Corporation": .bally,
    "Midway Manufacturing Company, a subsidiary of WMS Industries, Incorporated": .bally,
    "Bally Midway Manufacturing Company": .bally,
    "Barok Company": .barok,
    "Briarwood, A Division Of Brunswick Manufacturing Company": .brunswick,
    "Brunswick Manufacturing Company": .brunswick,
    "Capcom Coin-Op, Incorporated": .capcom,
    "Chicago Coin Machine Manufacturing Company": .chicagoCoin,
    "CIC Play, S.A.": .cicPlay,
    "Data East Pinball, Incorporated": .dataEast,
    "Daval Manufacturing Co.": .daval,
    "G.B. Daval Company Inc.": .daval,
    "Electromatic Brasil": .electromatic,
    "Eusebio Martinez Garcia": .emagar,
    "Exhibit Supply Company": .exhibit,
    "Game Plan, Incorporated": .gamePlan,
    "Geiger-Automatenbau GmbH": .geiger,
    "Genco Manufacturing Company": .genco,
    "D. Gottlieb & Company": .gottlieb,
    "D. Gottlieb & Company, a Columbia Pictures Industries Company": .gottlieb,
    "Premier Technology": .gottlieb,
    "Mylstar Electronics, Incorporated": .gottlieb,
    "Grand Products Incorporated": .grandProducts,
    "A. Hankin & Company": .hankin,
    "Hi-Skor Amusement Company": .hiSkor,
    "Hutchison Engineering Company": .hutchison,
    "Ideas y Diseños, Sociedad Anónima": .idsa,
    "In and Outdoor Games Company": .inOutdoor,
    "Industria (Electromecánica) de Recreativos S.A": .inder,
    "Interflip S. A.": .interflip,
    "O. D. Jennings and Company": .jennings,
    "J. F. Linck Corp.": .jFLinck,
    "J. P. Seeburg Corporation": .jpSeeburg,
    "Juegos Populares, S.A.": .juegosPopulares,
    "Jocmatic S.A.": .jocmatic,
    "Joctronic Juegos Electronicos S.A.": .joctronic,
    "J. H. Keeney and Company Incorporated": .keeney,
    "LTD do Brasil Diversões Eletrônicas Ltda": .ltdBrasil,
    "Maquinas Automaticas Computerizadas, S.A.": .mac,
    "Maquinas Recreativas Sociedad Anonima": .maresa,
    "Midway Manufacturing Company": .midway,
    "NSM Apparatebau KG": .nsm,
    "Pace Manufacturing Company Incorporated": .pace,
    "Pacific Amusement Manufacturing Company": .pamco,
    "Peo Manufacturing Corporation": .peo,
    "Procedimientos Electromagnéticos de Tanteo y Color": .petaco,
    "Pierce Tool and Manufacturing Company": .pierce,
    "Rally a.k.a. Rally Play Company": .rally,
    "Recel S. A.": .recel,
    "Rock-ola Manufacturing Corporation": .rockOla,
    "Rowamet Indústria Eletrometalúrgica LTDA": .rowamet,
    "Sega Pinball, Incorporated": .sega,
    "Sega Enterprises, Ltd.": .sega,
    "Sega of America": .sega,
    "Creaciones e Investigaciones Electrónicas, Sociedad Limitada": .sleic,
    "Segasa d.b.a. Sonic": .sonic,
    "Spinball": .spinball,
    "Spooky Pinball LLC": .spooky,
    "Sport matic, S.A.": .sportmatic,
    "Staal Society": .staal,
    "Stern Pinball, Incorporated": .stern,
    "Stern Electronics, Incorporated": .stern,
    "Stoner Manufacturing Company": .stoner,
    "U.S Tehkan Inc.": .tekhan,
    "Taito do Brasil, a division of Taito, Japan": .taitoBrasil,
    "Mecatronics, a.k.a. Taito (Brazil), a division of Taito": .taitoBrasil,
    "United Manufacturing Company": .united,
    "Universal de Desarrollos Electronicos, S.A.": .unidesa,
    "Video Dens, S.A.": .videoDens,
    "Wico Corporation": .wico,
    "Williams Electronics, Incorporated": .williams,
    "Williams Electronic Manufacturing Corporation": .williams,
    "Williams Manufacturing Company": .williams,
    "Williams Electronics Games, Incorporated, a subsidiary of WMS Ind., Incorporated": .williams,
]
