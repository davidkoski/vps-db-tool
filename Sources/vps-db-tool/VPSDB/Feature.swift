import Foundation

// TODO: suggested changes for master list
// mr -> mixed reality
// retheme
// DOF
// DT Only

/// https://github.com/VirtualPinballSpreadsheet/vps-frontend/blob/master/src/lib/types/VPin.ts#L129
enum TableFeature: String, Codable, Sendable, Equatable {
    case fourK = "4k"
    case adult = "Adult"
    case bam = "BAM"
    case dof = "DOF"
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
    case inclVideo = "incl. Video"
    case nFozzy = "nFozzy"
    case noROM = "no ROM"

    // to delete
    case mod2 = "Mod"
    case oldPatch = "Patch"
}

enum B2SFeature: String, Codable, Sendable {
    case screen2 = "2Screens"
    case screen3 = "3Screens"
    case fullDMD = "FullDMD"
    case inclTable = "incl. Table"
}
