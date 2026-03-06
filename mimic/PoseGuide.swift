import Foundation

struct PoseGuide: Hashable {
    let name: String
    let symbol: String
}

enum PoseGuideCatalog {
    static let byCategory: [String: [PoseGuide]] = [
        "cute": [
            PoseGuide(name: "ほっぺハート", symbol: "heart.fill"),
            PoseGuide(name: "ダブルピース", symbol: "hand.victory.fill")
        ],
        "cool": [
            PoseGuide(name: "腕組み", symbol: "person.fill"),
            PoseGuide(name: "サイドポーズ", symbol: "figure.walk")
        ],
        "funny": [
            PoseGuide(name: "びっくり顔", symbol: "face.smiling.inverse"),
            PoseGuide(name: "ジャンプポーズ", symbol: "figure.highintensity.intervaltraining")
        ]
    ]

    static let fallback = PoseGuide(name: "ピース", symbol: "hand.raised.fill")

    static func pick(from tags: Set<String>, excluding previous: PoseGuide? = nil) -> PoseGuide {
        let pool = tags.flatMap { byCategory[$0] ?? [] }
        let fallbackPool = byCategory.values.flatMap { $0 }
        let candidates = pool.isEmpty ? fallbackPool : pool
        let filtered = candidates.filter { $0 != previous }
        return (filtered.isEmpty ? candidates : filtered).randomElement() ?? fallback
    }
}
