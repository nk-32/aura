import CoreGraphics
import ImageIO
import UIKit

enum MomentImagePipeline {
    static let maxPixelSize: CGFloat = 2_000

    static func prepareDisplayImage(from data: Data, maxPixelSize: CGFloat = maxPixelSize) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    static func prepareDisplayImage(from image: UIImage, maxPixelSize: CGFloat = maxPixelSize) -> UIImage? {
        if let data = image.jpegData(compressionQuality: 0.9),
           let prepared = prepareDisplayImage(from: data, maxPixelSize: maxPixelSize) {
            return prepared
        }

        let largestEdge = max(image.size.width, image.size.height)
        guard largestEdge > maxPixelSize else {
            return image.normalizedImage()
        }

        let scale = maxPixelSize / largestEdge
        let targetSize = CGSize(
            width: max(image.size.width * scale, 1),
            height: max(image.size.height * scale, 1)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
