import Foundation
import Testing
@testable import Aura

struct AuraTests {
    @Test func analysisDescriptorsReflectSceneSignals() async throws {
        let analysis = MomentAnalysis(
            sceneLabels: ["Cafe", "Coffeehouse"],
            faceCount: 1,
            humanCount: 2,
            animalCount: 0,
            brightness: 0.61,
            warmth: 0.22,
            soundLevel: 0.38,
            capturedAt: .now
        )

        #expect(analysis.brightnessDescriptor == "自然光の中間トーン")
        #expect(analysis.warmthDescriptor == "肌に残るぬくもり")
        #expect(analysis.relationshipDescription.contains("ふたり"))
        #expect(analysis.sceneLine.contains("Cafe"))
    }

    @Test func tagsCaptureDominantContext() async throws {
        let analysis = MomentAnalysis(
            sceneLabels: ["Dog", "Park"],
            faceCount: 0,
            humanCount: 1,
            animalCount: 1,
            brightness: 0.2,
            warmth: -0.3,
            soundLevel: 0.8,
            capturedAt: .now
        )

        #expect(analysis.tags.contains("Dog"))
        #expect(analysis.tags.contains("ambient sound"))
        #expect(analysis.tags.contains("animal trace"))
    }
}
