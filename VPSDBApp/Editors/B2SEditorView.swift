import Logging
import SwiftUI
import VPSDB

private let log = Logger(label: "B2SEditorView")

/// Create or edit a ``B2S`` (backglass) for a single game.
///
/// Adds the B2S features and an image picker / cropper for the backglass
/// image to the common fields -- see ``ResourceEditor``.
struct B2SEditorView: View {
    @Binding var db: Database
    /// The source page when creating -- `nil` when editing an existing resource.
    var detail: DetailResult? = nil
    let games: [Game]
    let client: HTTPClient
    var b2s: B2S? = nil

    /// Called when finished: `true` after a successful save, `false` on failure.
    let onDone: (ResourceEditorDisposition) -> Void

    /// Size of the backglass image.
    static let imageSize = CGSize(width: 1000, height: 750)

    /// The selected source image + crop for the backglass image.
    @State private var crop: ImageCrop?

    @Environment(AppSettings.self) private var settings

    var body: some View {
        ResourceEditor(
            db: $db, detail: detail, games: games, client: client,
            resource: b2s, onDone: onDone,
            willSave: { b2s in
                if let crop {
                    let t = Task { [b2s] in
                        let url = try export(
                            imageDirectory: settings.imagesURL, id: b2s.id, crop: crop,
                            size: Self.imageSize)
                        return url
                    }
                    let url = try await t.value
                    b2s.imgUrl = url
                }
            }
        ) { b2s, context in
            Section("Features") {
                ForEach(B2SFeature.allCases, id: \.self) { feature in
                    Toggle(
                        feature.rawValue,
                        isOn: Binding {
                            b2s.wrappedValue.hasFeature(feature)
                        } set: { on in
                            b2s.wrappedValue.setFeature(feature, on)
                        })
                }
            }

            if let imgUrl = b2s.wrappedValue.imgUrl {
                CurrentImageSection(url: imgUrl)
            }

            ImageCropPicker(
                title: "Backglass Image", images: context.images, aspectRatio: Self.imageSize,
                client: client, crop: $crop)
        }
    }
}

#Preview {
    NavigationStack {
        B2SEditorView(
            db: .constant(Database()),
            detail: DetailResult(
                .list,
                url: URL(string: "https://vpuniverse.com/files/file/1234")!,
                kind: .b2s, name: "Example", author: "Someone", version: "1.0"),
            games: [Game(name: "Example")],
            client: HTTPClient(),
            onDone: { _ in }
        )
    }
}
