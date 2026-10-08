import Foundation
import Testing
import VPSDB

struct ScannerTests {
    
    func url(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources")!
    }

    @Test func testVPF() async throws {
        let url = url("vpf.html")
        
        let scanner = VPForumsScanner()
        let detail = try scanner.scanDetail(url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)!
        
        print(detail)
        
        #expect(detail.name == "Dogelon Mars Pinball")
        #expect(detail.version == "1.0")
        #expect(detail.author == "Cisano")
    }

    @Test func testVPU() async throws {
        let url = url("vpu.html")
        
        let scanner = VPUniverseScanner()
        let detail = try scanner.scanDetail(url: url, content: String(contentsOf: url, encoding: .utf8), kind: .table)!
        
        print(detail)
        
        #expect(detail.name == "Jolly Park Oktoberfest oly")
        #expect(detail.version == "1.0.0")
        #expect(detail.author == "oly2")
        #expect(detail.date?.timeIntervalSince1970 == 1706377662)
        #expect((detail.text ?? "").hasPrefix("First of all,"))
        #expect(detail.images.count == 3)
    }

}
