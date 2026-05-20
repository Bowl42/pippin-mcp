import Foundation
import NaturalLanguage

public struct NLAnalyzeResult: Codable, Sendable {
    public struct Token: Codable, Sendable {
        public let text: String
        public let lemma: String?
        public let lexicalClass: String?
    }
    public let dominantLanguage: String?
    public let sentiment: Double?           // -1.0 (negative) ... 1.0 (positive)
    public let tokens: [Token]
}

public enum NLAnalyze {
    public static func run(
        text: String,
        includeTokens: Bool = true,
        includeSentiment: Bool = true
    ) -> NLAnalyzeResult {
        let dominant = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue

        var sentiment: Double? = nil
        if includeSentiment {
            let tagger = NLTagger(tagSchemes: [.sentimentScore])
            tagger.string = text
            let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let raw = tag?.rawValue, let v = Double(raw) {
                sentiment = v
            }
        }

        var tokens: [NLAnalyzeResult.Token] = []
        if includeTokens {
            let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
            tagger.string = text
            let range = text.startIndex..<text.endIndex
            tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { lexTag, tokenRange in
                let word = String(text[tokenRange])
                let lemmaTag = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0
                tokens.append(.init(
                    text: word,
                    lemma: lemmaTag?.rawValue,
                    lexicalClass: lexTag?.rawValue
                ))
                return true
            }
        }

        return NLAnalyzeResult(dominantLanguage: dominant, sentiment: sentiment, tokens: tokens)
    }
}
