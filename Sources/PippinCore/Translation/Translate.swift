import Foundation
import Translation

public struct TranslateResult: Codable, Sendable {
    public let sourceLanguage: String
    public let targetLanguage: String
    public let translatedText: String
}

public enum Translate {
    /// Translate text using Apple's on-device Translation framework.
    ///
    /// Note: First-time use of a language pair triggers a system-level language
    /// pack download prompt. The caller's host process must be able to present UI
    /// or the request will fail.
    public static func run(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> TranslateResult {
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)

        let session = TranslationSession(installedSource: source, target: target)
        do {
            let response = try await session.translate(text)
            return TranslateResult(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                translatedText: response.targetText
            )
        } catch {
            throw PippinError.underlying("Translation failed: \(error)")
        }
    }
}
