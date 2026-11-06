import SwiftUI
import VPSDB

/// The editor for a ``GameResourceKind`` -- either creating a resource from a
/// scanned `detail` page or editing an existing `resource`.
struct KindEditorView: View {
    @Binding var db: Database
    let kind: GameResourceKind

    /// The source page when creating -- `nil` when editing.
    var detail: DetailResult? = nil

    let games: [Game]
    let client: HTTPClient

    /// The resource to edit -- must be of the type for `kind`.  `nil` to create.
    var resource: (any GameResource)? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    var body: some View {
        switch kind {
        case .wheelArt:
            WheelArtEditorView(
                db: $db, detail: detail, games: games, client: client,
                wheelArt: resource as? WheelArt, onDone: onDone)
        case .rule:
            RuleEditorView(
                db: $db, detail: detail, games: games, client: client,
                rule: resource as? Rules, onDone: onDone)
        case .rom:
            ROMEditorView(
                db: $db, detail: detail, games: games, client: client,
                rom: resource as? ROM, onDone: onDone)
        case .pupPack:
            PupPackEditorView(
                db: $db, detail: detail, games: games, client: client,
                pupPack: resource as? PupPack, onDone: onDone)
        case .altSound:
            AltSoundEditorView(
                db: $db, detail: detail, games: games, client: client,
                altSound: resource as? AltSound, onDone: onDone)
        case .pov:
            POVEditorView(
                db: $db, detail: detail, games: games, client: client,
                pov: resource as? POV, onDone: onDone)
        case .topper:
            TopperEditorView(
                db: $db, detail: detail, games: games, client: client,
                topper: resource as? Topper, onDone: onDone)
        case .mediaPack:
            MediaPackEditorView(
                db: $db, detail: detail, games: games, client: client,
                mediaPack: resource as? MediaPack, onDone: onDone)
        case .table:
            TableEditorView(
                db: $db, detail: detail, games: games, client: client,
                table: resource as? VPSDB.Table, onDone: onDone)
        case .b2s:
            B2SEditorView(
                db: $db, detail: detail, games: games, client: client,
                b2s: resource as? B2S, onDone: onDone)
        case .altColor:
            AltColorEditorView(
                db: $db, detail: detail, games: games, client: client,
                altColor: resource as? AltColors, onDone: onDone)
        case .tutorial:
            TutorialEditorView(
                db: $db, detail: detail, games: games, client: client,
                tutorial: resource as? Tutorial, onDone: onDone)
        case .game, .sound:
            ContentUnavailableView(
                "No editor for \(kind.rawValue)", systemImage: "pencil.slash")
        }
    }
}
