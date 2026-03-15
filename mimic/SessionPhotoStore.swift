import Foundation

enum SessionPhotoStore {
    private static let photosKey = "mimic.currentSessionPhotos"
    private static let sessionIdKey = "mimic.currentSessionId"

    static func startNewSession() {
        UserDefaults.standard.set([], forKey: photosKey)
        UserDefaults.standard.set(UUID().uuidString, forKey: sessionIdKey)
    }

    static func appendPhoto(_ url: URL) {
        var list = UserDefaults.standard.stringArray(forKey: photosKey) ?? []
        list.append(url.path)
        UserDefaults.standard.set(list, forKey: photosKey)
    }

    static func loadPhotos() -> [URL] {
        let list = UserDefaults.standard.stringArray(forKey: photosKey) ?? []
        return list.map { URL(fileURLWithPath: $0) }
    }

    static func currentSessionId() -> String {
        if let id = UserDefaults.standard.string(forKey: sessionIdKey) {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: sessionIdKey)
        return newId
    }

    static func loadMostRecent(limit: Int) -> [URL] {
        guard let folder = try? AppPhotoStore.ensureFolder() else { return [] }
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let sorted = items.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return leftDate > rightDate
        }
        return Array(sorted.prefix(max(limit, 0)))
    }
}
