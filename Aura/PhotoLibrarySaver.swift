import Photos
import UIKit

enum PhotoLibrarySaveError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "写真ライブラリへの保存が許可されていません。設定アプリで Aura の写真アクセスを許可してください。"
        case .saveFailed:
            return "写真の保存に失敗しました。もう一度試してください。"
        }
    }
}

struct PhotoLibrarySaver {
    func save(image: UIImage) async throws {
        guard await requestAuthorizationIfNeeded() else {
            throw PhotoLibrarySaveError.accessDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: image.jpegData(compressionQuality: 0.96) ?? Data(), options: nil)
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        default:
            return false
        }
    }
}
