import Testing

struct Test {

    @Test func testParseName() async throws {
        let db = testDatabase
        
        #expect(db.parseName("Flash") == ("Flash", nil, nil))
        #expect(db.parseName("Flash (Williams)") == ("Flash", .williams, nil))
        #expect(db.parseName("Flash (1984)") == ("Flash", nil, 1984))
        #expect(db.parseName("Flash - Williams 1984)") == ("Flash", .williams, 1984))
        #expect(db.parseName("Wuthering waves (Wheels)") == ("Wuthering waves", nil, nil))
    }

    @Test func testNameMatch() async throws {
        let db = testDatabase
        
        #expect(db.matchName("Flash") == [flash])
        #expect(db.matchName("Flash Gordon") == [flashGordon])
        #expect(db.matchName("Flash G") == [flashGordon])
        
        #expect(db.matchName("Flash (Bally)") == [flashGordon])
        #expect(db.matchName("Flash (Bally 1981)") == [flashGordon])
        #expect(db.matchName("Flash (Bally 1980)") == [])
        
        #expect(
            db.matchName("Star Trek").sorted() == [
                starTrek1, starTrek2, starTrek3
            ].sorted())
        #expect(db.matchName("Star Trek (Data East)") == [starTrek3])
    }

}
