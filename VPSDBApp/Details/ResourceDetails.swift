import SwiftUI
import VPSDB

// One detail view per GameResourceKind -- see ResourceDetailView for routing.

struct GameDetailView: View {
    let game: Game

    /// Called to show one of the game's resources.
    var onSelect: (GameResourceKind, String) -> Void = { _, _ in }

    var body: some View {
        DetailForm {
            Section {
                LabeledContent("Name", value: game.name)
                LabeledContent("Manufacturer", value: game.manufacturer.rawValue)
                OptionalRow("Year", game.year.map(String.init))
                OptionalRow("Type", game.type?.rawValue)
                OptionalRow("Players", game.players.map(String.init))
                OptionalRow("MPU", game.mpu)
                if !game.designers.isEmpty {
                    LabeledContent("Designers", value: game.designers.joined(separator: ", "))
                }
                if !game.theme.isEmpty {
                    LabeledContent(
                        "Theme", value: game.theme.map(\.rawValue).joined(separator: ", "))
                }
                if let ipdbUrl = game.ipdbUrl {
                    LabeledContent("IPDB") { Link(ipdbUrl.absoluteString, destination: ipdbUrl) }
                }
                DateRows(created: game.createdAt, updated: game.updatedAt)
                LabeledContent("ID", value: game.id)
                    .textSelection(.enabled)
            }

            GameResourcesSections(game: game) { kind, resource in
                Button {
                    onSelect(kind, resource.id)
                } label: {
                    HStack {
                        ResourceSummaryRow(resource: resource)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            URLsSection(urls: game.urls)
        }
    }
}

struct TableDetailView: View {
    let table: VPSDB.Table

    var body: some View {
        DetailForm {
            GameResourceSection(resource: table)
            Section("Table") {
                OptionalRow("Format", table.tableFormat?.rawValue)
                OptionalRow("Edition", table.edition)
                OptionalRow("File Name", table.gameFileName)
                OptionalRow("Parent", table.parentId)
                if !table.features.isEmpty {
                    LabeledContent(
                        "Features", value: table.features.map(\.rawValue).joined(separator: ", "))
                }
            }
        }
    }
}

struct B2SDetailView: View {
    let b2s: B2S

    var body: some View {
        DetailForm {
            GameResourceSection(resource: b2s)
        }
    }
}

struct TutorialDetailView: View {
    let tutorial: Tutorial

    var body: some View {
        DetailForm {
            Section("Tutorial") {
                LabeledContent("Title", value: tutorial.title)
                OptionalRow("YouTube ID", tutorial.youtubeId)
            }
            GameResourceSection(resource: tutorial)
        }
    }
}

struct ROMDetailView: View {
    let rom: ROM

    var body: some View {
        DetailForm {
            GameResourceSection(resource: rom)
        }
    }
}

struct PupPackDetailView: View {
    let pupPack: PupPack

    var body: some View {
        DetailForm {
            GameResourceSection(resource: pupPack)
        }
    }
}

struct AltColorDetailView: View {
    let altColor: AltColors

    var body: some View {
        DetailForm {
            GameResourceSection(resource: altColor)
            Section("Alt Color") {
                OptionalRow("Type", altColor.type)
                OptionalRow("File Name", altColor.fileName)
                OptionalRow("Folder", altColor.folder)
            }
        }
    }
}

struct AltSoundDetailView: View {
    let altSound: AltSound

    var body: some View {
        DetailForm {
            GameResourceSection(resource: altSound)
        }
    }
}

struct POVDetailView: View {
    let pov: POV

    var body: some View {
        DetailForm {
            GameResourceSection(resource: pov)
        }
    }
}

struct WheelArtDetailView: View {
    let wheelArt: WheelArt

    var body: some View {
        DetailForm {
            GameResourceSection(resource: wheelArt)
        }
    }
}

struct TopperDetailView: View {
    let topper: Topper

    var body: some View {
        DetailForm {
            GameResourceSection(resource: topper)
        }
    }
}

struct MediaPackDetailView: View {
    let mediaPack: MediaPack

    var body: some View {
        DetailForm {
            GameResourceSection(resource: mediaPack)
        }
    }
}

struct RuleDetailView: View {
    let rule: Rules

    var body: some View {
        DetailForm {
            GameResourceSection(resource: rule)
        }
    }
}

struct SoundDetailView: View {
    let sound: Sound

    var body: some View {
        DetailForm {
            GameResourceSection(resource: sound)
        }
    }
}
