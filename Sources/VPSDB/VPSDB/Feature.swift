import Foundation

/// https://github.com/VirtualPinballSpreadsheet/vps-frontend/blob/master/src/lib/types/VPin.ts#L129
public enum TableFeature: String, Codable, Sendable, Equatable {
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
    case inclNVRAM = "incl. nvram"
    case inclVideo = "incl. Video"
    case nFozzy = "nFozzy"
    case noROM = "no ROM"
    case vlm = "VLM"
}

public enum B2SFeature: String, Codable, Sendable {
    case screen2 = "2Screens"
    case screen3 = "3Screens"
    case fullDMD = "FullDMD"
    case inclTable = "incl. Table"
}
