import Foundation

struct PoseGuide: Hashable {
    let name: String
    let symbol: String
    let imageName: String?

    init(name: String, symbol: String, imageName: String? = nil) {
        self.name = name
        self.symbol = symbol
        self.imageName = imageName
    }
}

enum PoseGuideCatalog {
    static let byCategory: [String: [PoseGuide]] = [
        "cute": [
            PoseGuide(name: "シンクロハート", symbol: "heart.fill", imageName: "シンクロハート"),
            PoseGuide(name: "おんぶポーズ", symbol: "figure.2", imageName: "おんぶお手本"),
            PoseGuide(name: "フラミンゴ", symbol: "figure.stand", imageName: "フラミンゴお手本"),
            PoseGuide(name: "手を挙げろ", symbol: "hand.raised.fill", imageName: "手を挙げろお手本")
        ],
        "cool": [
            PoseGuide(name: "ハシゴステップ", symbol: "figure.walk", imageName: "ハシゴステップお手本"),
            PoseGuide(name: "ボスとサイドキック", symbol: "person.2.crop.square.stack.fill", imageName: "ボスとサイドキックお手本")
        ],
        "funny": [
            PoseGuide(name: "Vポーズ", symbol: "hand.victory.fill", imageName: "Vポーズお手本"),
            PoseGuide(name: "本日の主役", symbol: "star.fill", imageName: "本日の主役お手本"),
            PoseGuide(name: "こちらです", symbol: "hand.point.right.fill", imageName: "こちらですお手本"),
            PoseGuide(name: "この通り！", symbol: "checkmark.circle.fill", imageName: "この通りお手本")
        ]
    ]

    static let fallback = PoseGuide(name: "ピース", symbol: "hand.raised.fill")

    static func pick(from tags: Set<String>, excluding previous: PoseGuide? = nil) -> PoseGuide {
        let pool = tags.flatMap { byCategory[$0] ?? [] }
        let fallbackPool = byCategory.values.flatMap { $0 }
        let candidates = pool.isEmpty ? fallbackPool : pool
        let filtered = candidates.filter { $0 != previous }
        let available = filtered.filter { PoseReferenceStore.angles(for: $0.name) != nil }
        if let picked = (available.isEmpty ? filtered : available).randomElement() {
            return picked
        }
        return fallback
    }
}
