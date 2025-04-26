import Foundation

// mr -> mixed reality
// retheme
// DOF
// DT Only

// 2screens
// 3screens
// FullDMD
// incl. Table

/// https://github.com/VirtualPinballSpreadsheet/vps-frontend/blob/master/src/lib/types/VPin.ts#L129
enum TableFeature: String, Codable, Sendable {
    case fourK = "4k"
    case adult = "Adult"
    case audio = "Audio"  // delete
    case bam = "BAM"
    case dof = "DOF"
    case dt = "DT"  // delete
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
    case mr = "MR"
    case mixedReality = "Mixed Reality"
    case music = "Music"
    case proc = "P-ROC"
    case ssf = "SSF"
    case scorbit = "Scorbit"
    case vr = "VR"
    case inclArt = "incl. Art"
    case inclB2S = "incl. B2S"
    case inclPuP = "incl. PuP"
    case inclROM = "incl. ROM"
    case inclVideo = "incl. Video"
    case nFozzy = "nFozzy"
    case noROM = "no ROM"
}

enum B2SFeature: String, Codable, Sendable {
    case screen2 = "2Screens"
    case screen3 = "3Screens"
    case fullDMD = "FullDMD"
    case inclTable = "incl. Table"
}
