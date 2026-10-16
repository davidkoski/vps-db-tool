import Testing
import VPSDB

@Suite
struct FileGameNameTests {

    @Test(arguments: [
        ("truck-stop_wheel-2026_ByPM.png", "truck stop"),
        ("Twilight_Zone.pov", "Twilight Zone"),
        ("Truck Stop (Bally 1988).png", "Truck Stop (Bally 1988)"),
        ("truck-stop (Bally 1988)_wheel.png", "truck stop (Bally 1988)"),
        ("2001_wheel.png", "2001"),
        ("Medieval Madness.png", "Medieval Madness"),
        ("attack-from-mars_by_someone.png", "attack from mars"),
        ("Black Knight 2000.png", "Black Knight 2000"),
        ("wheel.png", "wheel"),
    ])
    func testGameName(fileName: String, expected: String) {
        #expect(gameName(fromFileName: fileName) == expected)
    }
}
