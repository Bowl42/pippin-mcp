import Foundation
import FoundationModels

public struct FMGenerateResult: Codable, Sendable {
    public let text: String
}

public enum FMGenerate {
    public static func isAvailable() -> Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    public static func availabilityDescription() -> String {
        switch SystemLanguageModel.default.availability {
        case .available: return "available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "device not eligible for Apple Intelligence"
            case .appleIntelligenceNotEnabled: return "Apple Intelligence is not enabled in System Settings"
            case .modelNotReady: return "language model is not ready (still downloading?)"
            @unknown default: return "unavailable: \(reason)"
            }
        @unknown default: return "unknown"
        }
    }

    /// One-shot generation (non-streaming).
    public static func run(
        prompt: String,
        instructions: String? = nil,
        temperature: Double? = nil
    ) async throws -> FMGenerateResult {
        guard isAvailable() else {
            throw PippinError.capabilityUnavailable("Foundation Models: \(availabilityDescription())")
        }
        let session: LanguageModelSession
        if let instructions {
            session = LanguageModelSession(instructions: Instructions(instructions))
        } else {
            session = LanguageModelSession()
        }
        var options = GenerationOptions()
        if let t = temperature { options.temperature = t }
        do {
            let response = try await session.respond(to: prompt, options: options)
            return FMGenerateResult(text: response.content)
        } catch {
            throw PippinError.underlying("Foundation Models generation failed: \(error)")
        }
    }

    /// Streaming generation. Yields cumulative text snapshots.
    public static func stream(
        prompt: String,
        instructions: String? = nil,
        temperature: Double? = nil
    ) throws -> AsyncThrowingStream<String, Error> {
        guard isAvailable() else {
            throw PippinError.capabilityUnavailable("Foundation Models: \(availabilityDescription())")
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session: LanguageModelSession
                    if let instructions {
                        session = LanguageModelSession(instructions: Instructions(instructions))
                    } else {
                        session = LanguageModelSession()
                    }
                    var options = GenerationOptions()
                    if let t = temperature { options.temperature = t }
                    let responseStream = session.streamResponse(to: prompt, options: options)
                    for try await partial in responseStream {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
