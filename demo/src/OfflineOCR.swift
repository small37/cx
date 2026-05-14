import AppKit
import Foundation
import Vision

enum OfflineOCRError: LocalizedError {
    case imageLoadFailed
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            return "无法读取截图图像"
        case .noTextFound:
            return "未识别到文本"
        }
    }
}

final class OfflineOCR {
    func recognizeText(imageURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOf: imageURL),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                completion(.failure(OfflineOCRError.imageLoadFailed))
                return
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let text = (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if text.isEmpty {
                    completion(.failure(OfflineOCRError.noTextFound))
                } else {
                    completion(.success(text))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
