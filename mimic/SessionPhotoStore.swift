import Foundation

enum SessionPhotoStore {
    private static let photosKey = "mimic.currentSessionPhotos"

    static func startNewSession() {
        UserDefaults.standard.set([], forKey: photosKey)
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
}
