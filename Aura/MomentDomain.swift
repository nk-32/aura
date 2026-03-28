import Foundation

struct MomentAnalysis: Equatable, Sendable {
    let sceneLabels: [String]
    let faceCount: Int
    let humanCount: Int
    let animalCount: Int
    let brightness: Double
    let warmth: Double
    let soundLevel: Double?
    let capturedAt: Date

    var brightnessDescriptor: String {
        switch brightness {
        case ..<0.22:
            return "夜に沈む低照度"
        case ..<0.45:
            return "やわらかい薄明かり"
        case ..<0.72:
            return "自然光の中間トーン"
        default:
            return "強い光が差すハイライト"
        }
    }

    var warmthDescriptor: String {
        switch warmth {
        case ..<(-0.18):
            return "青みのある冷たい温度感"
        case ..<0.08:
            return "空気の温度が静かに均衡"
        case ..<0.28:
            return "肌に残るぬくもり"
        default:
            return "夕焼けめいた熱量"
        }
    }

    var soundDescriptor: String {
        guard let soundLevel else { return "音情報は未取得" }
        switch soundLevel {
        case ..<0.18:
            return "息づかいだけが残る静けさ"
        case ..<0.45:
            return "会話の余韻が漂う"
        case ..<0.72:
            return "街のざわめきが近い"
        default:
            return "高揚した音圧が場を包む"
        }
    }

    var relationshipDescription: String {
        if humanCount >= 3 {
            return "複数の人の流れが重なっている"
        }
        if humanCount == 2 {
            return "ふたりの距離感が画面の中心にある"
        }
        if humanCount == 1 && animalCount > 0 {
            return "ひとりと小さな相棒の関係が立ち上がる"
        }
        if faceCount == 1 {
            return "ひとりの気配が輪郭を持っている"
        }
        if animalCount > 0 {
            return "動物の存在感が場のリズムを作っている"
        }
        if let first = sceneLabels.first {
            return "\(first) が空気の主役になっている"
        }
        return "余白が広く、空気だけが前に出ている"
    }

    var sceneLine: String {
        if sceneLabels.isEmpty {
            return "視覚ラベルを絞り込めませんでした"
        }

        return sceneLabels.prefix(3).joined(separator: " / ")
    }

    var metadataLine: String {
        [
            timeBucket,
            brightnessDescriptor,
            warmthDescriptor
        ].joined(separator: " · ")
    }

    var timeBucket: String {
        let hour = Calendar.current.component(.hour, from: capturedAt)
        switch hour {
        case 5..<11:
            return "Morning"
        case 11..<17:
            return "Daylight"
        case 17..<21:
            return "Blue Hour"
        default:
            return "Late Night"
        }
    }

    var tags: [String] {
        var items = [brightnessDescriptor, warmthDescriptor]
        if let first = sceneLabels.first {
            items.append(first)
        }
        if let soundLevel, soundLevel > 0.18 {
            items.append("ambient sound")
        }
        if humanCount > 1 {
            items.append("human connection")
        }
        if animalCount > 0 {
            items.append("animal trace")
        }
        return Array(Set(items)).sorted()
    }

    var promptSummary: String {
        """
        明るさ: \(brightnessDescriptor)
        温度感: \(warmthDescriptor)
        音: \(soundDescriptor)
        関係性: \(relationshipDescription)
        シーン: \(sceneLine)
        時間帯: \(timeBucket)
        """
    }
}

struct MomentPoem: Equatable, Sendable {
    enum Typography: String, Equatable, Sendable {
        case halo
        case pulse
        case drift
        case ember
    }

    let title: String
    let poem: String
    let emotion: String
    let typography: Typography
    let accentWord: String
    let sourceLabel: String
}

struct GeneratedMoment: Equatable, Sendable {
    let analysis: MomentAnalysis
    let poem: MomentPoem
}
