import CommonCrypto
import Foundation

enum BaiduTranslateError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "未配置百度翻译 APP_ID 或密钥"
        case .invalidResponse:
            return "百度翻译返回数据无效"
        case .apiError(let message):
            return message
        }
    }
}

final class BaiduTranslator {
    private let endpoint = URL(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!
    private let cacheQueue = DispatchQueue(label: "sleepguard.baidu.translate.cache")
    private var translationCache: [String: CacheEntry] = [:]
    private var inflight: [String: [(Result<String, Error>) -> Void]] = [:]

    func translate(_ text: String, to targetLanguage: String = "zh", completion: @escaping (Result<String, Error>) -> Void) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "\(targetLanguage)|\(normalizedText)"

        if let cached = cachedTranslation(for: key) {
            completion(.success(cached))
            return
        }

        if enqueueInflightIfNeeded(for: key, completion: completion) {
            return
        }

        guard let appID = credential(named: "BAIDU_TRANSLATE_APP_ID", defaultKey: "BaiduTranslateAppID"),
              let secret = credential(named: "BAIDU_TRANSLATE_SECRET", defaultKey: "BaiduTranslateSecret") else {
            finishInflight(for: key, with: .failure(BaiduTranslateError.missingCredentials))
            return
        }

        let salt = String(Int(Date().timeIntervalSince1970 * 1000))
        let sign = md5(appID + normalizedText + salt + secret)
        let bodyItems = [
            "q": normalizedText,
            "from": "auto",
            "to": targetLanguage,
            "appid": appID,
            "salt": salt,
            "sign": sign
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(from: bodyItems).data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                self.finishInflight(for: key, with: .failure(error))
                return
            }
            guard let data else {
                self.finishInflight(for: key, with: .failure(BaiduTranslateError.invalidResponse))
                return
            }
            let result = self.parse(data: data)
            if case .success(let translated) = result {
                self.storeTranslation(translated, for: key)
            }
            self.finishInflight(for: key, with: result)
        }.resume()
    }

    private func cachedTranslation(for key: String) -> String? {
        cacheQueue.sync {
            guard let entry = translationCache[key], entry.expireAt > Date() else {
                return nil
            }
            return entry.value
        }
    }

    private func enqueueInflightIfNeeded(for key: String, completion: @escaping (Result<String, Error>) -> Void) -> Bool {
        cacheQueue.sync {
            if inflight[key] != nil {
                inflight[key]?.append(completion)
                return true
            }
            inflight[key] = [completion]
            return false
        }
    }

    private func finishInflight(for key: String, with result: Result<String, Error>) {
        let callbacks: [(Result<String, Error>) -> Void] = cacheQueue.sync {
            let blocks = inflight[key] ?? []
            inflight[key] = nil
            return blocks
        }
        for cb in callbacks {
            cb(result)
        }
    }

    private func storeTranslation(_ value: String, for key: String) {
        cacheQueue.async {
            if self.translationCache.count >= 200 {
                self.translationCache.removeAll(keepingCapacity: true)
            }
            self.translationCache[key] = CacheEntry(value: value, expireAt: Date().addingTimeInterval(300))
        }
    }

    private func credential(named environmentKey: String, defaultKey: String) -> String? {
        let configKey = defaultKey == "BaiduTranslateAppID" ? "appID" : "secret"
        if let configValue = AppConfig.string(section: "baiduTranslate", key: configKey) {
            return configValue
        }

        let environmentValue = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentValue, !environmentValue.isEmpty {
            return environmentValue
        }

        let defaultsValue = UserDefaults.standard.string(forKey: defaultKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return defaultsValue?.isEmpty == false ? defaultsValue : nil
    }

    private func parse(data: Data) -> Result<String, Error> {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                return .failure(BaiduTranslateError.invalidResponse)
            }
            if let errorCode = dictionary["error_code"] as? String {
                let message = dictionary["error_msg"] as? String ?? "百度翻译错误 \(errorCode)"
                return .failure(BaiduTranslateError.apiError(message))
            }
            guard let results = dictionary["trans_result"] as? [[String: Any]] else {
                return .failure(BaiduTranslateError.invalidResponse)
            }
            let translated = results.compactMap { $0["dst"] as? String }.joined(separator: "\n")
            return translated.isEmpty ? .failure(BaiduTranslateError.invalidResponse) : .success(translated)
        } catch {
            return .failure(error)
        }
    }

    private func formBody(from items: [String: String]) -> String {
        items.map { key, value in
            "\(escape(key))=\(escape(value))"
        }
        .joined(separator: "&")
    }

    private func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func md5(_ value: String) -> String {
        let data = Data(value.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private struct CacheEntry {
        let value: String
        let expireAt: Date
    }
}
