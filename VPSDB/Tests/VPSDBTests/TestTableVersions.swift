import Foundation
import Testing
import VPSDB

@Suite
struct TestTableVersions {

    @Test func testCanonicalVersion() {
        #expect(canonicalVersion("3.01") != canonicalVersion("3.0"))
        #expect(canonicalVersion("2.0") != canonicalVersion("2.0.1"))
        #expect(canonicalVersion("2.0") == canonicalVersion("2.0.0"))
        #expect(canonicalVersion("2.1") != canonicalVersion("2.0.1"))
        #expect(canonicalVersion("2.0") == canonicalVersion("2.00"))
        #expect(canonicalVersion("Version2.0") == canonicalVersion("2.0"))
    }

    @Test(arguments: [
        ("v1.01 PUP and Non-PUP", "1.01"),
        ("RAMBO V2.0", "2"),
        ("Version 2.00", "2"),
        ("v2", "2"),
        ("1.10", "1.10"),
        ("3.01", "3.01"),
        ("2.0.1", "2.0.1"),
        ("FizX3.3 V1.10", "1.10"),
        ("FixZ 3.3 V1.20", "1.20"),
        (" FizX3.3 V1.00", "1"),
        ("FizX3.3 V1.00", "1"),
        ("v1.1 & v2.0", "2"),
        ("v2.0 & v1.1", "2"),
        ("1.9 and 1.10", "1.10"),
        ("1.1, 2.0", "2"),
        ("v1.2.5 [DT, FS, B2S]", "1.2.5"),
        ("1.0 B2S", "1"),
        ("v1.1f 2020-01-28", "1.1f"),
        ("2020-01-28 v1.1f", "1.1f"),
        ("v1.105 b", "1.105b"),
        ("1.0b2", "1b2"),
        ("1.2 ai", "1.2"),
        ("1.4.3fr", "1.4.3"),
        ("1.0a", "1a"),
        ("1.0A", "1a"),
        ("2.0a", "2a"),
        ("1.2b", "1.2b"),
        ("2.0SE", "2"),
        ("1.0 WIP", "1"),
        ("1,1", "1.1"),
        ("Beta 1.1.0", "1.1"),
        ("2026-09-17", "2026-09-17"),
        ("Final", "Final"),
        ("", ""),
    ])
    func testCanonicalVersionFromPage(input: String, expected: String) {
        #expect(canonicalVersion(input) == expected)
    }

    @Test func testCanonicalVersionDistinguishes() {
        #expect(canonicalVersion("1.0a") != canonicalVersion("1.0b"))
        #expect(canonicalVersion("1.10") != canonicalVersion("1.1"))
        #expect(canonicalVersion("2026-09-17") != canonicalVersion("2026-10-06"))
        #expect(canonicalVersion("v1.01 PUP and Non-PUP") == canonicalVersion("1.01"))
        #expect(canonicalVersion("RAMBO V2.0") == canonicalVersion("2.0"))
        #expect(canonicalVersion("v1.1 & v2.0") == canonicalVersion("2.0"))
        #expect(canonicalVersion("FizX3.3 V1.00") == canonicalVersion("1.0"))
        #expect(canonicalVersion("v1.2.5 [DT, FS, B2S]") == canonicalVersion("1.2.5"))
        #expect(canonicalVersion("v1.1f 2020-01-28") == canonicalVersion("1.1f"))
        #expect(canonicalVersion("v1.105 b") == canonicalVersion("1.105b"))
        #expect(canonicalVersion("1.0b2") != canonicalVersion("1.0b3"))
    }
}
