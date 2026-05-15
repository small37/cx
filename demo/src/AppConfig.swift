import Foundation

enum AppConfig {
    static let url = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".touchbar-island")
        .appendingPathComponent("config.json")

    static func loadDictionary() -> [String: Any] {
        cacheQueue.sync {
            ensureDefaultConfigExists()
            let modifiedAt = fileModifiedDate() ?? .distantPast
            if let cached = cachedDictionary,
               let cachedAt = cachedModifiedAt,
               cachedAt >= modifiedAt {
                return cached
            }

            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let dictionary = object as? [String: Any] else {
                cachedDictionary = defaultDictionary
                cachedModifiedAt = modifiedAt
                return defaultDictionary
            }

            cachedDictionary = dictionary
            cachedModifiedAt = modifiedAt
            return dictionary
        }
    }

    static func string(section: String, key: String) -> String? {
        let dictionary = loadDictionary()
        let sectionDictionary = dictionary[section] as? [String: Any]
        let value = sectionDictionary?[key] as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func ensureDefaultConfigExists() {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            write(defaultDictionary)
            return
        }

        guard var dictionary = mutableDictionary() else { return }
        var changed = false

        if dictionary["hotkeys"] == nil {
            dictionary["hotkeys"] = defaultDictionary["hotkeys"]
            changed = true
        }
        if dictionary["baiduTranslate"] == nil {
            dictionary["baiduTranslate"] = defaultDictionary["baiduTranslate"]
            changed = true
        }

        if changed {
            write(dictionary)
        }
    }

    private static func mutableDictionary() -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private static func write(_ dictionary: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: url, options: .atomic)
        cachedDictionary = dictionary
        cachedModifiedAt = fileModifiedDate() ?? Date()
    }

    private static func fileModifiedDate() -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    private static let cacheQueue = DispatchQueue(label: "sleepguard.appconfig.cache")
    private static var cachedDictionary: [String: Any]?
    private static var cachedModifiedAt: Date?

    private static let defaultDictionary: [String: Any] = [
        "hotkeys": [
            "text": "option+a",
            "screenshot": "option+s"
        ],
        "baiduTranslate": [
            "appID": "20190801000323312",
            "secret": "dEw4vh5iViUqGEVcIPan"
        ]
    ]
}
