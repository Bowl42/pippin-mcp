import Foundation
import Vision
import CoreImage

public struct ClassificationResult: Codable, Sendable {
    public struct Label: Codable, Sendable {
        public let identifier: String
        public let confidence: Double
    }
    public let labels: [Label]
}

public enum Classify {
    public static func run(
        image: CIImage,
        maxResults: Int = 10,
        minConfidence: Double = 0.1
    ) async throws -> ClassificationResult {
        let request = ClassifyImageRequest()
        let observations: [ClassificationObservation]
        do {
            observations = try await request.perform(on: image)
        } catch {
            throw PippinError.underlying("Vision classify failed: \(error)")
        }
        let labels = observations
            .filter { Double($0.confidence) >= minConfidence }
            .prefix(maxResults)
            .map { ClassificationResult.Label(identifier: $0.identifier, confidence: Double($0.confidence)) }
        return ClassificationResult(labels: Array(labels))
    }
}
