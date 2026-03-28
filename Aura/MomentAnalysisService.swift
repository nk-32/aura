import CoreImage
import ImageIO
import UIKit
import Vision

actor MomentAnalysisService {
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    func analyze(image: UIImage, soundLevel: Double?) async throws -> MomentAnalysis {
        guard let cgImage = image.cgImage else {
            throw MomentAnalysisError.invalidImage
        }

        let averageColor = averageRGB(for: image) ?? SIMD3<Double>(repeating: 0.5)
        let brightness = (averageColor.x + averageColor.y + averageColor.z) / 3
        let warmth = averageColor.x - averageColor.z

        let handler = ImageRequestHandler(cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
        var classify = ClassifyImageRequest()
        classify.cropAndScaleAction = .centerCrop
        let faceRequest = DetectFaceRectanglesRequest()
        var humanRequest = DetectHumanRectanglesRequest()
        humanRequest.upperBodyOnly = false
        let animalRequest = RecognizeAnimalsRequest()

        let (classifications, faces, humans, animals) = try await handler.perform(
            classify,
            faceRequest,
            humanRequest,
            animalRequest
        )

        let sceneLabels = topSceneLabels(from: classifications, animals: animals)

        return MomentAnalysis(
            sceneLabels: sceneLabels,
            faceCount: faces.count,
            humanCount: humans.count,
            animalCount: animals.count,
            brightness: brightness,
            warmth: warmth,
            soundLevel: soundLevel,
            capturedAt: .now
        )
    }

    private func topSceneLabels(
        from classifications: [ClassificationObservation],
        animals: [RecognizedObjectObservation]
    ) -> [String] {
        let visionLabels = classifications
            .filter { $0.confidence > 0.12 }
            .prefix(4)
            .map(\.identifier)

        let animalLabels = animals
            .compactMap { $0.labels.first?.identifier }

        return NSOrderedSet(array: (visionLabels + animalLabels).map(cleanLabel))
            .array
            .compactMap { $0 as? String }
            .prefix(4)
            .map { $0 }
    }

    private func cleanLabel(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: ",")
            .first
            .map(String.init)?
            .capitalized ?? raw.capitalized
    }

    private func averageRGB(for image: UIImage) -> SIMD3<Double>? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent
        guard !extent.isEmpty else { return nil }

        let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: extent)
            ]
        )

        guard let output = filter?.outputImage else { return nil }

        var rgba = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return SIMD3(
            Double(rgba[0]) / 255,
            Double(rgba[1]) / 255,
            Double(rgba[2]) / 255
        )
    }
}

enum MomentAnalysisError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "画像を解析できませんでした。別の写真で試してください。"
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
