import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

actor MomentPoet {
    private var inferenceFailureDescription: String?

    func composePoem(from analysis: MomentAnalysis) async -> MomentPoem {
        #if targetEnvironment(simulator)
        return fallbackPoem(from: analysis, sourceLabel: "Simulator fallback")
        #else
        #if canImport(FoundationModels)
        guard inferenceFailureDescription == nil else {
            return fallbackPoem(from: analysis, sourceLabel: "On-device fallback")
        }

        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            if model.isAvailable, model.supportsLocale(Locale(identifier: "ja_JP")) {
                do {
                    return try await composeWithAppleIntelligence(analysis: analysis, model: model)
                } catch {
                    inferenceFailureDescription = error.localizedDescription
                    return fallbackPoem(from: analysis, sourceLabel: "On-device fallback")
                }
            }
        }
        #endif

        return fallbackPoem(from: analysis, sourceLabel: "On-device fallback")
        #endif
    }

    func availabilitySummary() -> String {
        #if targetEnvironment(simulator)
        return "Simulator fallback"
        #else
        #if canImport(FoundationModels)
        if inferenceFailureDescription != nil {
            return "On-device fallback"
        }

        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Apple Intelligence"
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "Unsupported device"
                case .appleIntelligenceNotEnabled:
                    return "Enable Apple Intelligence"
                case .modelNotReady:
                    return "Model preparing"
                @unknown default:
                    return "Model unavailable"
                }
            }
        }
        #endif

        return "Local fallback"
        #endif
    }

    private func fallbackPoem(from analysis: MomentAnalysis, sourceLabel: String) -> MomentPoem {
        let title: String
        let poem: String
        let emotion: String
        let accent: String
        let typography: MomentPoem.Typography

        switch analysis.warmth {
        case ..<(-0.15):
            title = "Quiet Blue"
            poem = "冷えた光の縁で\n言葉だけがゆっくり残る"
            emotion = "静かな余白"
            accent = "blue"
            typography = .drift
        case ..<0.18:
            title = "Soft Static"
            poem = "薄いざわめきの中で\nまだ名づかない気持ちが揺れる"
            emotion = "ためらい"
            accent = "hush"
            typography = .halo
        default:
            title = "After Glow"
            poem = "熱の残る空気ごと\nいまの気分をそっと焼きつける"
            emotion = "高鳴り"
            accent = "glow"
            typography = .ember
        }

        let adjustedPoem: String
        if analysis.humanCount >= 2 {
            adjustedPoem = poem + "\nふたりの距離が温度になる"
        } else if analysis.soundLevel ?? 0 > 0.65 {
            adjustedPoem = poem + "\nざわめきが鼓動みたいに跳ねる"
        } else {
            adjustedPoem = poem
        }

        return MomentPoem(
            title: title,
            poem: adjustedPoem,
            emotion: emotion,
            typography: typography,
            accentWord: accent,
            sourceLabel: sourceLabel
        )
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private extension MomentPoet {
    @Generable
    struct AIOverlay {
        let title: String
        let poem: String
        let emotion: String
        let typographyStyle: String
        let accentWord: String
    }

    func composeWithAppleIntelligence(
        analysis: MomentAnalysis,
        model: SystemLanguageModel
    ) async throws -> MomentPoem {
        let session = LanguageModelSession(model: model) {
            """
            You write poetic overlays for a camera app.
            Always answer in Japanese.
            The title is 2 to 5 words.
            The poem is 18 to 42 Japanese characters, split into 2 or 3 short lines.
            The emotion is 1 to 4 Japanese words.
            The typographyStyle must be one of: halo, pulse, drift, ember.
            The accentWord must be a single lowercase English word.
            Avoid hashtags, emoji, and quotes.
            """
        }

        let prompt = """
        次の空気感をもとに、写真の右下に刻む短いポエムを作ってください。

        \(analysis.promptSummary)
        """

        let response = try await session.respond(
            to: prompt,
            generating: AIOverlay.self,
            options: GenerationOptions(
                temperature: 1.15,
                maximumResponseTokens: 120
            )
        )

        return MomentPoem(
            title: response.content.title.trimmingCharacters(in: .whitespacesAndNewlines),
            poem: response.content.poem.trimmingCharacters(in: .whitespacesAndNewlines),
            emotion: response.content.emotion.trimmingCharacters(in: .whitespacesAndNewlines),
            typography: normalizeTypography(response.content.typographyStyle),
            accentWord: normalizeAccentWord(response.content.accentWord),
            sourceLabel: "Apple Intelligence"
        )
    }

    func normalizeTypography(_ raw: String) -> MomentPoem.Typography {
        switch raw.lowercased() {
        case "pulse":
            return .pulse
        case "drift":
            return .drift
        case "ember":
            return .ember
        default:
            return .halo
        }
    }

    func normalizeAccentWord(_ raw: String) -> String {
        let cleaned = raw
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init) ?? "glow"

        return cleaned.isEmpty ? "glow" : cleaned
    }
}
#endif
