import Combine
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class MomentComposerViewModel: ObservableObject {
    @Published var sourceImage: UIImage?
    @Published var generatedMoment: GeneratedMoment?
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var modelSummary = "Checking…"
    @Published var ambientLevel = 0.0

    private let analysisService = MomentAnalysisService()
    private let poet = MomentPoet()
    private let audioMonitor = AmbientAudioMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var generationTask: Task<Void, Never>?

    init() {
        audioMonitor.$level
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.ambientLevel = level ?? 0
            }
            .store(in: &cancellables)
    }

    func prepare() async {
        modelSummary = await poet.availabilitySummary()
        await audioMonitor.start()
    }

    func loadPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "写真の読み込みに失敗しました。"
                return
            }

            let image = await Task.detached(priority: .userInitiated) {
                MomentImagePipeline.prepareDisplayImage(from: data)
            }.value

            guard let image else {
                errorMessage = "写真の読み込みに失敗しました。"
                return
            }

            composeMoment(from: image, isPreparedForDisplay: true)
        } catch {
            errorMessage = "写真の読み込みに失敗しました。"
        }
    }

    func composeMoment(from image: UIImage, isPreparedForDisplay: Bool = false) {
        generationTask?.cancel()

        sourceImage = nil
        generatedMoment = nil
        errorMessage = nil
        isGenerating = true

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let preparedImage = if isPreparedForDisplay {
                    image
                } else {
                    await Task.detached(priority: .userInitiated) {
                        MomentImagePipeline.prepareDisplayImage(from: image) ?? image
                    }.value
                }

                if Task.isCancelled { return }

                self.sourceImage = preparedImage

                let analysis = try await self.analysisService.analyze(
                    image: preparedImage,
                    soundLevel: self.ambientLevel
                )
                let poem = await self.poet.composePoem(from: analysis)

                if Task.isCancelled { return }

                self.generatedMoment = GeneratedMoment(analysis: analysis, poem: poem)
                self.modelSummary = await self.poet.availabilitySummary()
                self.isGenerating = false
            } catch {
                if Task.isCancelled { return }
                self.errorMessage = error.localizedDescription
                self.isGenerating = false
            }
        }
    }

    var ambientLevelLabel: String {
        switch ambientLevel {
        case ..<0.18:
            return "quiet"
        case ..<0.45:
            return "soft"
        case ..<0.72:
            return "alive"
        default:
            return "loud"
        }
    }

    deinit {
        generationTask?.cancel()
        Task { @MainActor [audioMonitor] in
            audioMonitor.stop()
        }
    }
}
