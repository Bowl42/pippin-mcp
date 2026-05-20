import Foundation
import Vision
import CoreImage

public struct OCRResult: Codable, Sendable {
    public struct Block: Codable, Sendable {
        public let text: String
        public let confidence: Double
        public let boundingBox: BoundingBox
    }
    public struct BoundingBox: Codable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
    }

    public let text: String
    public let blocks: [Block]
    public let detectedLanguages: [String]
}

public enum OCRLevel: String, Codable, Sendable {
    case fast, accurate
}

public enum OCR {
    public static func recognize(
        image: CIImage,
        languages: [String] = [],
        level: OCRLevel = .accurate,
        usesLanguageCorrection: Bool = true
    ) async throws -> OCRResult {
        var request = RecognizeTextRequest()
        request.recognitionLevel = level == .fast ? .fast : .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        if !languages.isEmpty {
            request.recognitionLanguages = languages.map { Locale.Language(identifier: $0) }
        }

        let observations: [RecognizedTextObservation]
        do {
            observations = try await request.perform(on: image)
        } catch {
            throw PippinError.underlying("Vision OCR failed: \(error)")
        }

        var blocks: [OCRResult.Block] = []
        var lines: [String] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            lines.append(candidate.string)
            let bb = obs.boundingBox.cgRect
            blocks.append(.init(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                boundingBox: .init(x: Double(bb.origin.x), y: Double(bb.origin.y), width: Double(bb.size.width), height: Double(bb.size.height))
            ))
        }

        return OCRResult(
            text: lines.joined(separator: "\n"),
            blocks: blocks,
            detectedLanguages: languages
        )
    }
}
