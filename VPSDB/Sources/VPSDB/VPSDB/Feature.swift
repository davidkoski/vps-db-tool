import Foundation
import OrderedCollections

private struct ScanPattern<T: Sendable>: Sendable {
    nonisolated(unsafe) let pattern: any RegexComponent
    let result: T

    init(_ pattern: any RegexComponent, _ result: T) {
        self.pattern = pattern
        self.result = result
    }
}

private let tableFeaturePatterns: [ScanPattern<TableFeature>] = [
    .init(/fozzy/.ignoresCase(), .nFozzy),
    .init(/fleep/.ignoresCase(), .fleep),
    .init(/vr ?room/.ignoresCase(), .vr),
    .init(/mixed reality/.ignoresCase(), .mr),
    .init(/hybrid/.ignoresCase(), .hybrid),
    .init(/scorbit/.ignoresCase(), .scorbit),
    .init(/fizx/.ignoresCase(), .fizX),
    .init(/\bBAM\b/, .bam),
    .init(/\bVPU Remix\b/, .patch),
]

private let tableCommentPatterns: [ScanPattern<String>] = [
    .init(/sideblade/.ignoresCase(), "Sideblade Mod"),
    .init(/side blade/.ignoresCase(), "Sideblade Mod"),
]

/// https://github.com/VirtualPinballSpreadsheet/vps-frontend/blob/master/src/lib/types/VPin.ts#L129
public enum TableFeature: String, Codable, Sendable, Equatable, CaseIterable {
    case fourK = "4k"
    case adult = "Adult"
    case bam = "BAM"
    case dof = "DOF"
    case dt = "DT"
    case dtOnly = "DT only"
    case fss = "FSS"
    case fastFlips = "FastFlips"
    case fizX = "FizX"
    case fleep = "Fleep"
    case flexDMD = "FlexDMD"
    case hybrid = "Hybrid"
    case kids = "Kids"
    case lut = "LUT"
    case mod = "MOD"
    case retheme = "Retheme"
    case mr = "MR"
    case mixedReality = "Mixed Reality"
    case music = "Music"
    case patch = "VPU Patch"
    case proc = "P-ROC"
    case ssf = "SSF"
    case scorbit = "Scorbit"
    case vr = "VR"
    case inclArt = "incl. Art"
    case inclB2S = "incl. B2S"
    case inclPuP = "incl. PuP"
    case inclROM = "incl. ROM"
    case inclNVRAM = "incl. nvram"
    case inclVideo = "incl. Video"
    case nFozzy = "nFozzy"
    case noROM = "no ROM"
    case vlm = "VLM"

    public static func scan(_ text: String?) -> Set<TableFeature> {
        guard let text else { return [] }

        return
            tableFeaturePatterns
            .filter { text.contains($0.pattern) }
            .map { $0.result }
            .set()
    }
}

public func scanTableText(_ text: (String?)...) -> String? {
    scanText(text, tableCommentPatterns)
}

private let b2sFeaturePatterns: [ScanPattern<B2SFeature>] = [
    .init(/\b2 screen\b/.ignoresCase(), .screen2),
    .init(/\b3 screen\b/.ignoresCase(), .screen3),
    .init(/\b2screen\b/.ignoresCase(), .screen2),
    .init(/\b3screen\b/.ignoresCase(), .screen3),
    .init(/\bfull dmd\b/.ignoresCase(), .fullDMD),
    .init(/\bfulldmd\b/.ignoresCase(), .fullDMD),
]

private let b2sCommentPatterns: [ScanPattern<String>] = [
    .init(/\balternate\b/.ignoresCase(), "Alternate"),
    .init(/\balt\b/.ignoresCase(), "Alternate"),
]

public enum B2SFeature: String, Codable, Sendable, CaseIterable {
    case screen2 = "2Screens"
    case screen3 = "3Screens"
    case fullDMD = "FullDMD"
    case inclTable = "incl. Table"

    public static func scan(_ text: String?) -> Set<B2SFeature> {
        guard let text else { return [] }

        return
            b2sFeaturePatterns
            .filter { text.contains($0.pattern) }
            .map { $0.result }
            .set()
    }
}

public func scanB2Text(_ text: (String?)...) -> String? {
    scanText(text, b2sCommentPatterns)
}

private func combine(_ pieces: [String?]) -> String? {
    let pieces = pieces.compactMap { $0 }
    if pieces.isEmpty { return nil }
    return pieces.joined(separator: " ")
}

private func scanText(_ text: [String?], _ patterns: [ScanPattern<String>]) -> String? {
    guard let text = combine(text) else { return nil }

    let result =
        patterns
        .filter { text.contains($0.pattern) }
        .map { $0.result }

    if result.isEmpty {
        return nil
    } else {
        return OrderedSet(result).joined(separator: " ")
    }
}

private let wheelPatterns: [ScanPattern<String>] = [
    .init(/animated/.ignoresCase(), "Animated"),
    .init(/neon/.ignoresCase(), "Neon"),
    .init(/glass orb/.ignoresCase(), "Glass Orb"),
    .init(/blue ring/.ignoresCase(), "Blue Ring"),
    .init(/\blogo\b/.ignoresCase(), "Logo"),
    .init(/diagonal/.ignoresCase(), "Diagonal"),
    .init(/pup pack wheel/.ignoresCase(), "PuP Pack Wheel"),
]

public func scanWheelText(_ text: (String?)...) -> String? {
    scanText(text, wheelPatterns)
}

private let rulePatterns: [ScanPattern<String>] = [
    .init(/\bgerman\b/.ignoresCase(), "German"),
    .init(/\bdeutch\b/.ignoresCase(), "German"),
    .init(/\bfrench\b/.ignoresCase(), "French"),
    .init(/\bfrançais\b/.ignoresCase(), "French"),
    .init(/\bspanish\b/.ignoresCase(), "Spanish"),
    .init(/\bespañol\b/.ignoresCase(), "Spanish"),
    .init(/\bvideo\b/.ignoresCase(), "Video"),
]

public func scanRuleText(_ text: (String?)...) -> String? {
    scanText(text, rulePatterns)
}

private let povPatterns: [ScanPattern<String>] = [
    .init(/\b3d\b/.ignoresCase(), "3D Anaglyph"),
    .init(/\bforced perspective\b/.ignoresCase(), "Forced Perspective"),
]

public func scanPOVText(_ text: (String?)...) -> String? {
    scanText(text, povPatterns)
}

/// The ROM name from the first zip file mentioned in the text:
/// `"... download amh_022.zip ..."` -> `amh_022`.
public func scanROMName(_ text: String?) -> String? {
    guard let text,
        let match = text.firstMatch(of: /([A-Za-z0-9][A-Za-z0-9_\-]*)\.zip\b/.ignoresCase())
    else { return nil }
    return String(match.1)
}

private let altSoundPatterns: [ScanPattern<String>] = [
    .init(/\bgerman\b/.ignoresCase(), "German"),
    .init(/\bdeutch\b/.ignoresCase(), "German"),
    .init(/\bfrench\b/.ignoresCase(), "French"),
    .init(/\bfrançais\b/.ignoresCase(), "French"),
    .init(/\bspanish\b/.ignoresCase(), "Spanish"),
    .init(/\bespañol\b/.ignoresCase(), "Spanish"),
]

public func scanAltSoundText(_ text: (String?)...) -> String? {
    scanText(text, altSoundPatterns)
}

