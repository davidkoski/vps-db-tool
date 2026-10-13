import Foundation
import Testing
import VPSDB

struct ROMNameTests {

    @Test(arguments: [
        ("Rom file: amh_022.zip for Amazon Hunt", "amh_022"),
        ("AMH_022.ZIP", "AMH_022"),
        ("file sttng_l7.zip, and sttng_l7c.zip", "sttng_l7"),
        ("t2_l8.zip.", "t2_l8"),
    ])
    func testROMName(text: String, name: String) {
        #expect(scanROMName(text) == name)
    }

    @Test(arguments: ["no zip here", "see foo.zipper", ""])
    func testNoROMName(text: String) {
        #expect(scanROMName(text) == nil)
    }

    @Test func testNil() {
        #expect(scanROMName(nil) == nil)
    }
}
