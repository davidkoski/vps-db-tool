import Foundation

/// The game name from a file name in a pack (wheel art, POVs, ...), for
/// matching with ``Database/matchName(_:)``:
///
/// - `truck-stop_wheel-2026_ByPM.png` -> `truck stop`
/// - `Twilight_Zone.pov` -> `Twilight Zone`
/// - `Truck Stop (Bally 1988).png` -> `Truck Stop (Bally 1988)`
/// - `2001_wheel.png` -> `2001`
///
/// Words are separated by `_`, `-`, `.` or spaces.  The name ends at the
/// first word (after the first) describing the file rather than the game: a
/// kind (`wheel`, `pov`, ...) or an author (`by`, `ByPM`).  Years are kept --
/// they can be part of the name (`Black Knight 2000`).  A parenthesized part is
/// kept -- `matchName` uses the manufacturer / year in it.
public func gameName(fromFileName fileName: String) -> String {
    var base = (fileName as NSString).deletingPathExtension

    // "(Bally 1988)" -- set aside, it has its own separators and year
    var details: String?
    if let match = base.firstMatch(of: /\(([^)]*)\)/) {
        details = String(match.output.1).trimmingCharacters(in: .whitespaces)
        base.removeSubrange(match.range)
    }

    let words = base.split { $0 == "_" || $0 == "-" || $0 == "." || $0.isWhitespace }
        .map(String.init)

    var name = [String]()
    for word in words {
        if !name.isEmpty && isFileWord(word) {
            break
        }
        name.append(word)
    }

    if name.isEmpty {
        name = words
    }

    var result = name.joined(separator: " ")
    if let details, !details.isEmpty {
        result += " (\(details))"
    }
    return result
}

/// Words that describe the file (its kind) rather than the game.
private let fileKindWords: Set<String> = [
    "wheel", "wheels", "pov", "povs", "logo", "logos", "backglass", "b2s", "topper",
    "toppers", "dmd", "art",
]

private func isFileWord(_ word: String) -> Bool {
    let lower = word.lowercased()
    if fileKindWords.contains(lower) {
        return true
    }
    // "by", or an author tag like "ByPM"
    if lower == "by" {
        return true
    }
    if word.hasPrefix("By"), word.count > 2,
        word[word.index(word.startIndex, offsetBy: 2)].isUppercase
    {
        return true
    }
    return false
}
