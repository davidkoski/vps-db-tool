import CoreImage
import CoreImage.CIFilterBuiltins
import VPSDB
import WebP

func export(
    imageDirectory: URL, id: String, crop: ImageCrop, size: CGSize
) throws -> URL {
    let ts = Int(Date().timeIntervalSince1970)
    let filename = "\(id)_\(ts).webp"
    let url = imageDirectory.appendingPathComponent(filename)

    let context = CIContext()
    let source = CIImage(cgImage: crop.image)

    let xs = size.width / crop.pixelRect.size.width
    let ys = size.height / crop.pixelRect.size.width
    let scale = min(max(xs, ys), 1)
    let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
    let scaledSize = source.extent.applying(scaleTransform)

    // rescale into an integral rect -- no fractional pixels via clamp
    let scaled =
        if scale != 1 {
            source
                .clampedToExtent()
                .transformed(by: scaleTransform, highQualityDownsample: true)
        } else {
            source
        }

    // scale the unit rect back to the pixel size
    let pixelScale = CGAffineTransform(
        scaleX: scaledSize.width,
        y: scaledSize.height)

    // the crop rect is at 0, 0 in the upper left -- convert to quadrant 1
    let unitRect = crop.rect
    let x = unitRect.origin.x
    let y = unitRect.origin.y
    let height = unitRect.size.height
    let origin = CGPoint(x: x, y: 1 - y - height)

    // scale to pixel coordinates and offset to center of pixel
    let pixelCrop = CGRect(origin: origin, size: unitRect.size)
        .applying(pixelScale)
        .applying(.init(translationX: 0.5, y: 0.5))

    let cropped = scaled.cropped(to: pixelCrop)

    let cs = CGColorSpace(name: CGColorSpace.sRGB)
    let raster = context.createCGImage(cropped, from: pixelCrop, format: .RGBX8, colorSpace: cs)!

    let encoder = WebPEncoder()
    var config = WebPEncoderConfig.preset(.drawing, quality: 50)
    config.method = 6
    config.snsStrength = 80
    config.filterStrength = 60
    let data = try encoder.encode(raster, config: config)

    try data.write(to: url, options: .withoutOverwriting)

    return imageBase.appendingPathComponent(filename)
}
