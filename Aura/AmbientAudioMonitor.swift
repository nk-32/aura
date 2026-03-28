import AVFoundation
import Combine
import Foundation

@MainActor
final class AmbientAudioMonitor: NSObject, ObservableObject {
    @Published private(set) var level: Double?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() async {
        #if targetEnvironment(simulator)
        level = nil
        return
        #endif

        guard await requestPermission() else {
            level = nil
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ambient-meter.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            startTimer()
        } catch {
            level = nil
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.18, target: self, selector: #selector(updateMeter), userInfo: nil, repeats: true)
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    @objc private func updateMeter() {
        guard let recorder else { return }
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (averagePower + 50) / 50))
        level = Double(normalized)
    }
}
