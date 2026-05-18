import CoreGraphics
import Foundation
import ImageIO
import Vision

protocol ScreenshotTextRecognizing: Sendable {
  func recognizeText(in url: URL) async -> String?
}

struct VisionScreenshotTextRecognizer: ScreenshotTextRecognizing {
  func recognizeText(in url: URL) async -> String? {
    await Task.detached(priority: .utility) {
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
      }

      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true

      let handler = VNImageRequestHandler(cgImage: image, options: [:])
      do {
        try handler.perform([request])
      } catch {
        return nil
      }

      let text = request.results?
        .compactMap { observation in
          observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      guard let text, !text.isEmpty else {
        return nil
      }

      return text
    }.value
  }
}
