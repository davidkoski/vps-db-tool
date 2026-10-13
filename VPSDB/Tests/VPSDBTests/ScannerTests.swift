import Foundation
import Testing

@testable import VPSDB

struct ScannerTests {

    func url(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources")!
    }

    @Test func testVPFVersion() {
        let scanner = VPForumsScanner()

        #expect(
            scanner.splitName("Count-Down (Gottlieb 1978) JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0")
                == ("Count-Down (Gottlieb 1978)", "2.0"))
        #expect(scanner.splitName("Cerberus wheel") == ("Cerberus", "1.0"))
        #expect(
            scanner.splitName("Boxster Pinball (JPSalas 2010).png") == (
                "Boxster Pinball (Original 2010)", "1.0"
            ))
        #expect(scanner.splitName("Lady Sharpshooter Backglass") == ("Lady Sharpshooter", "1.0"))

        // no parens: a trailing version comes off the name
        #expect(scanner.splitName("Close Encounters 1.4.3") == ("Close Encounters", "1.4.3"))
        // ... but a number that isn't version-like is part of the name
        #expect(scanner.splitName("Space 1999") == ("Space 1999", "1.0"))
        // unrecognized parens are kept in the name
        #expect(scanner.splitName("Foo (Remastered) 1.2") == ("Foo (Remastered)", "1.2"))
        // more parens after the version
        #expect(
            scanner.splitName("Name (Williams 1990) v1.2 (VR)") == ("Name (Williams 1990)", "v1.2"))
        // tokens with digits that aren't versions
        #expect(
            scanner.splitName("Medieval Madness (Williams 1997) Remake VR2") == (
                "Medieval Madness (Williams 1997)", "1.0"
            ))
    }

    @Test func testVPF() async throws {
        let url = url("vpf.html")

        let scanner = VPForumsScanner()
        let detail = try scanner.scanDetail(
            url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)!

        #expect(detail.name == "Dogelon Mars Pinball")
        #expect(detail.version == "1.0")
        #expect(detail.author == "Cisano")
        #expect(detail.date.timeIntervalSince1970 == 1_706_030_940)
        #expect((detail.text ?? "").hasPrefix("My first Pinball with simple"))
        #expect(detail.images.count == 1)
    }

    @Test func testVPF1() async throws {
        let url = url("vpf-1.html")

        let scanner = VPForumsScanner()
        let detail = try scanner.scanDetail(
            url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)!

        #expect(detail.name == "Cerberus")
        #expect(detail.version == "1.0")
        #expect(detail.author == "deadmanworking")
        #expect(detail.date.timeIntervalSince1970 == 1_768_096_440)
        #expect((detail.text ?? "").hasPrefix("Cerberus wheel created from backglass"))
        #expect(detail.images.count == 1)
    }

    @Test func testVPU() async throws {
        let url = url("vpu.html")

        let scanner = VPUniverseScanner()
        let detail = try scanner.scanDetail(
            url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)!

        #expect(detail.name == "Jolly Park Oktoberfest oly")
        #expect(detail.version == "1.0.0")
        #expect(detail.author == "oly2")
        #expect(detail.date.timeIntervalSince1970 == 1_706_377_662)
        #expect((detail.text ?? "").hasPrefix("First of all,"))
        #expect(detail.images.count == 3)
    }

    @Test func testYoutube() async throws {
        // a channel list
        let url = url("youtube.html")

        let scanner = YouTubeScanner()
        let list = try scanner.scanList(
            url: url, content: String(contentsOf: url, encoding: .utf8), kind: .tutorial)

        #expect(list.list.count == 83)
        #expect(list.list[3].name == "Dr. Dude and His Excellent Ray Pinball Tutorial")
        #expect(list.list[3].author == "Digital Victory")
    }

    @Test func testPinballNirvanaList() throws {
        let url = url("pinballnirvana-1.html")

        let scanner = PinballNirvanaScanner()
        let list = try scanner.scanList(
            url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)

        #expect(list.list.count == 25)
        #expect(list.list[0].name == "Uncomposed Arrangement (Lunar Howl 9)")
        #expect(list.list[0].author == "Anthias")
    }

    @Test func testPinballNirvanaDetail() throws {
        let url = url("pinballnirvana-2.html")

        let scanner = PinballNirvanaScanner()
        let detail = try scanner.scanDetail(
            url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)!

        #expect(detail.name == "Uncomposed Arrangement (Lunar Howl 9)")
        #expect(detail.author == "Anthias")
        #expect(detail.version == "1.0")
        #expect((detail.text ?? "").hasPrefix("This is a MOD"))
        #expect(detail.images.count == 4)
    }

}
