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
    }
}
