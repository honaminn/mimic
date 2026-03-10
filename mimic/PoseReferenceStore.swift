import Foundation

enum PoseReferenceStore {
    private static var cached: [String: PoseAngles] = [:]
    private static var didLoad = false

    static func angles(for poseName: String) -> PoseAngles? {
        if !didLoad {
            didLoad = true
            cached = loadFromBundle()
        }
        return cached[poseName]
    }

    private static func loadFromBundle() -> [String: PoseAngles] {
        guard let url = Bundle.main.url(forResource: "PoseReferences", withExtension: "json") else {
            return [:]
        }
        guard let data = try? Data(contentsOf: url) else { return [:] }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else {
            return [:]
        }

        var result: [String: PoseAngles] = [:]
        for (name, angles) in raw {
            var values: [PoseAngleKey: Double] = [:]
            for (key, value) in angles {
                if let angleKey = PoseAngleKey(rawValue: key) {
                    values[angleKey] = value
                }
            }
            if !values.isEmpty {
                result[name] = PoseAngles(values: values)
            }
        }
        return result
    }
}
