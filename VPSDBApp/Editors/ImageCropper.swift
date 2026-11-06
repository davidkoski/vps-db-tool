import CoreGraphics
import ImageIO
import SwiftUI
import VPSDB

/// A crop of a source image.
struct ImageCrop: Equatable {
    /// Where the source image came from.
    var url: URL

    /// The full size source image -- the same `CGImage` the cropper displays.
    /// If rotated, this is the rotated image (and `rect` is relative to it).
    var image: CGImage

    /// The selected region, normalized (0...1) with a top-left origin.
    var rect: CGRect

    /// Clockwise quarter turns applied to the downloaded image (0...3) --
    /// informational, `image` is already rotated.
    var quarterTurns = 0

    /// Pixel size of the source image.
    var imageSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// The selected region in source image pixels.
    var pixelRect: CGRect {
        CGRect(
            x: rect.minX * imageSize.width, y: rect.minY * imageSize.height,
            width: rect.width * imageSize.width, height: rect.height * imageSize.height)
    }

    static func == (lhs: ImageCrop, rhs: ImageCrop) -> Bool {
        // compare the image by identity -- it's the same decoded image unless reloaded
        lhs.url == rhs.url && lhs.image === rhs.image && lhs.rect == rhs.rect
    }
}

/// Section to pick one of the page's images and crop it to `aspectRatio`.
///
/// The crop is reported via `crop` -- the image processing is up to the caller.
struct ImageCropPicker: View {
    var title: LocalizedStringKey = "Image"
    let images: [URL]

    /// Output size -- only the aspect ratio matters for the crop
    /// (e.g. 402 x 302 for a backglass).
    let aspectRatio: CGSize

    let client: HTTPClient
    @Binding var crop: ImageCrop?

    @State private var selected: URL?

    /// Images added by the user (dropped / entered) -- e.g. images that are
    /// in the page text rather than its metadata.
    @State private var addedImages = [URL]()

    @State private var urlText = ""
    @State private var isDropTargeted = false

    /// The page's images, the added ones and the current crop's image.
    private var allImages: [URL] {
        var result = images
        for url in addedImages + [crop?.url].compactMap({ $0 }) where !result.contains(url) {
            result.append(url)
        }
        return result
    }

    var body: some View {
        Section(title) {
            Group {
                if allImages.isEmpty {
                    Text("No images on the page -- drop an image here or enter its URL")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 75)
                } else {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(allImages, id: \.self) { url in
                                thumbnail(url)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
            }
            // e.g. an image dragged from a browser (its URL) or Finder (a file URL)
            .dropDestination(for: URL.self) { urls, _ in
                add(urls)
                return !urls.isEmpty
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }

            HStack {
                TextField("Image URL", text: $urlText)
                    .onSubmit(addEnteredURL)
                Button("Add") { addEnteredURL() }
                    .disabled(enteredURL == nil)
            }

            if let selected {
                ImageCropper(
                    url: selected, aspectRatio: aspectRatio, client: client, crop: $crop
                )
                // fresh state per image
                .id(selected)
                Button("No Image") {
                    self.selected = nil
                    crop = nil
                }
            } else if !allImages.isEmpty {
                Text("Select an image to crop")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            selected = crop?.url
        }
    }

    /// The entered URL, if it looks like one.
    private var enteredURL: URL? {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), Self.isImageSource(url) else { return nil }
        return url
    }

    private func addEnteredURL() {
        guard let url = enteredURL else { return }
        add([url])
        urlText = ""
    }

    /// Add images and select the (first) new one.
    private func add(_ urls: [URL]) {
        let urls = urls.filter(Self.isImageSource)
        for url in urls where !allImages.contains(url) {
            addedImages.append(url)
        }
        if let first = urls.first {
            selected = first
        }
    }

    private static func isImageSource(_ url: URL) -> Bool {
        url.isFileURL || (["http", "https"].contains(url.scheme) && url.host() != nil)
    }

    private func thumbnail(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            default:
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 100, height: 75)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.accentColor, lineWidth: selected == url ? 3 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selected = url
        }
        .help(url.absoluteString)
    }
}

/// Crop an image to a fixed aspect ratio: drag to position, zoom with the
/// slider or a pinch.  The image always covers the crop area.
struct ImageCropper: View {
    let url: URL
    let aspectRatio: CGSize
    let client: HTTPClient
    @Binding var crop: ImageCrop?

    /// The crop area on screen fits in this box (portrait and landscape).
    var maxViewport = CGSize(width: 480, height: 480)
    var maxZoom: CGFloat = 8

    @State private var image: CGImage?
    @State private var error: String?

    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var dragStart: CGSize?
    @State private var zoomStart: CGFloat?

    /// Clockwise quarter turns applied to the downloaded image.
    @State private var quarterTurns = 0

    private var viewport: CGSize {
        let scale = min(
            maxViewport.width / aspectRatio.width, maxViewport.height / aspectRatio.height)
        return CGSize(width: aspectRatio.width * scale, height: aspectRatio.height * scale)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Group {
                if let image {
                    cropArea(image)
                } else if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .frame(width: viewport.width, height: viewport.height)
                } else {
                    ProgressView()
                        .frame(width: viewport.width, height: viewport.height)
                }
            }
            .background(.quaternary)
            .overlay {
                Rectangle().strokeBorder(.secondary)
            }

            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $zoom, in: 1 ... maxZoom) {
                    Text("Zoom")
                } onEditingChanged: { editing in
                    if !editing { commit() }
                }
                .labelsHidden()
                Image(systemName: "plus.magnifyingglass")
                Button("Reset") {
                    zoom = 1
                    offset = .zero
                    commit()
                }
                Button("Rotate", systemImage: "rotate.right") {
                    rotate()
                }
                .labelStyle(.iconOnly)
                .help("Rotate 90° clockwise")
            }
            .frame(width: max(viewport.width, 320))
            .disabled(image == nil)
            .onChange(of: zoom) {
                // keep the image covering the crop area as it shrinks
                if let geometry { offset = geometry.clamp(offset, zoom: zoom) }
            }

            if let crop, crop.url == url {
                cropInfo(crop)
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private var geometry: CropGeometry? {
        image.map {
            CropGeometry(image: CGSize(width: $0.width, height: $0.height), viewport: viewport)
        }
    }

    private func cropArea(_ image: CGImage) -> some View {
        let geometry = CropGeometry(
            image: CGSize(width: image.width, height: image.height), viewport: viewport)
        let scale = geometry.scale(zoom: zoom)

        let drag = DragGesture()
            .onChanged { value in
                let start = dragStart ?? offset
                dragStart = start
                offset = geometry.clamp(
                    CGSize(
                        width: start.width + value.translation.width,
                        height: start.height + value.translation.height),
                    zoom: zoom)
            }
            .onEnded { _ in
                dragStart = nil
                commit()
            }

        let magnify = MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? zoom
                zoomStart = start
                zoom = min(max(start * value.magnification, 1), maxZoom)
                offset = geometry.clamp(offset, zoom: zoom)
            }
            .onEnded { _ in
                zoomStart = nil
                commit()
            }

        return Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            .offset(offset)
            .frame(width: viewport.width, height: viewport.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(drag.simultaneously(with: magnify))
    }

    private func cropInfo(_ crop: ImageCrop) -> some View {
        let pixels = crop.pixelRect
        let lowResolution = pixels.width < aspectRatio.width - 0.5
        return HStack {
            Text(
                "Crop \(Int(pixels.width.rounded())) × \(Int(pixels.height.rounded())) of \(Int(crop.imageSize.width)) × \(Int(crop.imageSize.height)) → \(Int(aspectRatio.width)) × \(Int(aspectRatio.height))"
            )
            if lowResolution {
                Label("Upscaled", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("The crop has fewer pixels than the output size")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func load() async {
        // re-selecting the image of the current crop: reuse its decoded image
        if let crop, crop.url == url {
            quarterTurns = crop.quarterTurns
            show(crop.image)
            return
        }

        do {
            // dropped files are local -- the http client only does http(s)
            let data = url.isFileURL ? try Data(contentsOf: url) : try await client.get(url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                error = "Unable to decode image"
                return
            }
            show(image)
        } catch {
            self.error = "Unable to load image: \(error.localizedDescription)"
        }
    }

    /// Display a loaded (full size) image, restoring the crop if it's of this image.
    private func show(_ image: CGImage) {
        self.image = image

        let geometry = CropGeometry(
            image: CGSize(width: image.width, height: image.height), viewport: viewport)

        if let crop, crop.url == url {
            // restore the previous crop of this image
            (zoom, offset) = geometry.state(for: crop.rect, maxZoom: maxZoom)
        } else {
            zoom = 1
            offset = .zero
        }
        commit()
    }

    /// Report the current crop.
    /// Rotate the image 90° clockwise -- the crop starts over (fill, centered).
    private func rotate() {
        guard let image, let rotated = rotatedClockwise(image) else { return }
        quarterTurns = (quarterTurns + 1) % 4
        self.image = rotated
        zoom = 1
        offset = .zero
        commit()
    }

    private func commit() {
        guard let image, let geometry else { return }
        let new = ImageCrop(
            url: url, image: image, rect: geometry.rect(zoom: zoom, offset: offset),
            quarterTurns: quarterTurns)
        if new != crop {
            crop = new
        }
    }
}

/// The image rotated 90° clockwise (as sRGB, 8 bits per component).
func rotatedClockwise(_ image: CGImage) -> CGImage? {
    let w = image.width
    let h = image.height
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: h, height: w, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .none
    // y-up coordinates: rotate -90° (clockwise), then shift back into the canvas
    context.translateBy(x: 0, y: CGFloat(w))
    context.rotate(by: -.pi / 2)
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return context.makeImage()
}

/// The math relating the on-screen zoom / offset to the crop rect.
///
/// At zoom 1 the image fills the viewport (aspect fill); `offset` is the
/// image center relative to the viewport center, in points.
struct CropGeometry {
    let image: CGSize
    let viewport: CGSize

    var fillScale: CGFloat {
        max(viewport.width / image.width, viewport.height / image.height)
    }

    func scale(zoom: CGFloat) -> CGFloat {
        fillScale * zoom
    }

    /// Limit the offset so the image always covers the viewport.
    func clamp(_ offset: CGSize, zoom: CGFloat) -> CGSize {
        let s = scale(zoom: zoom)
        let maxX = max(0, (image.width * s - viewport.width) / 2)
        let maxY = max(0, (image.height * s - viewport.height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY))
    }

    /// The visible region, normalized with a top-left origin.
    func rect(zoom: CGFloat, offset: CGSize) -> CGRect {
        let s = scale(zoom: zoom)
        let x = ((image.width * s - viewport.width) / 2 - offset.width) / s
        let y = ((image.height * s - viewport.height) / 2 - offset.height) / s
        return CGRect(
            x: x / image.width, y: y / image.height,
            width: viewport.width / s / image.width, height: viewport.height / s / image.height)
    }

    /// Inverse of ``rect(zoom:offset:)``.
    func state(for rect: CGRect, maxZoom: CGFloat) -> (zoom: CGFloat, offset: CGSize) {
        guard rect.width > 0 else { return (1, .zero) }
        let s = viewport.width / (rect.width * image.width)
        let zoom = min(max(s / fillScale, 1), maxZoom)
        let scale = scale(zoom: zoom)
        let offset = CGSize(
            width: (image.width * scale - viewport.width) / 2 - rect.minX * image.width * scale,
            height: (image.height * scale - viewport.height) / 2 - rect.minY * image.height * scale)
        return (zoom, clamp(offset, zoom: zoom))
    }
}
