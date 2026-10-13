import Foundation
import Testing
import VPSDB

struct ParsedGameNameTests {

    @Test func testUnknownManufacturer() {
        // unknown manufacturer: leave it blank but keep the name and year
        #expect(
            ParsedGameName("Saw  - The final game (RSI 2026)")
                == ParsedGameName(name: "Saw - The final game", year: 2026))
    }

    @Test func testManufacturerYear() {
        #expect(
            ParsedGameName("Medieval Madness (Williams 1997)")
                == ParsedGameName(name: "Medieval Madness", manufacturer: .williams, year: 1997))
        #expect(
            ParsedGameName("Hurricane (williams, 1991)")
                == ParsedGameName(name: "Hurricane", manufacturer: .williams, year: 1991))
    }

    @Test func testPartial() {
        #expect(ParsedGameName("Name (1985)") == ParsedGameName(name: "Name", year: 1985))
        #expect(
            ParsedGameName("Name (Williams)")
                == ParsedGameName(name: "Name", manufacturer: .williams))
    }

    @Test func testPlainName() {
        #expect(ParsedGameName("Just A Name") == ParsedGameName(name: "Just A Name"))
        #expect(ParsedGameName("  Spaced   Out  ") == ParsedGameName(name: "Spaced Out"))
    }

    @Test func testUnrecognizedParens() {
        // nothing recognizable in the parens -- keep them in the name
        #expect(ParsedGameName("Name (Remastered)") == ParsedGameName(name: "Name (Remastered)"))
        // text after the parens is ignored
        #expect(
            ParsedGameName("Tron (Stern 2011) Mod")
                == ParsedGameName(name: "Tron", manufacturer: .stern, year: 2011))
    }

    @Test func testReleaseTitle() {
        let title = ReleaseTitle(
            "Count-Down (Gottlieb 1978) JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0")
        #expect(title.name == "Count-Down")
        #expect(title.title == "Count-Down (Gottlieb 1978)")
        #expect(title.details == "Gottlieb 1978")
        #expect(title.manufacturer == .gottlieb)
        #expect(title.year == 1978)
        #expect(title.suffix == "JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0")
        #expect(title.version == "2.0")
    }

    @Test(arguments: ["2.0", "1.4.3", "v5.5", "v2", "V1.0", "1.2b"])
    func testIsVersion(token: String) {
        #expect(ReleaseTitle("Name \(token)").version == token)
    }

    @Test(arguments: ["2010", "Ext2k", "VR2", "2", "(1.0)"])
    func testIsNotVersion(token: String) {
        #expect(ReleaseTitle("Name \(token)").version == nil)
    }
}
