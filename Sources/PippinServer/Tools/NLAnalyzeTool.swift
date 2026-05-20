import Foundation
import MCP
import PippinCore

public enum NLAnalyzeTool: PippinTool {
    public static let name = "nl_analyze"
    public static let title = "Natural Language Analysis"
    public static let description = """
    Analyze text using Apple's NaturalLanguage framework. Detects the dominant \
    language (BCP-47 tag), computes a sentiment score from -1.0 (negative) to \
    1.0 (positive), and optionally tokenizes the text with per-token lemma and \
    lexical class (noun/verb/etc). Entirely offline. \
    Use this for quick language-aware preprocessing of text.
    """

    struct Input: Codable {
        let text: String
        let includeTokens: Bool?
        let includeSentiment: Bool?
    }

    public static var outputSchema: Value? {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "dominantLanguage": ["type": ["string","null"], "description": "BCP-47 tag (e.g. 'en', 'zh-Hans'); null if undetectable"],
                "sentiment": ["type": ["number","null"], "minimum": -1, "maximum": 1, "description": "-1.0 (negative) ... 1.0 (positive); null if disabled"],
                "tokens": JSONSchema.array(items: [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string"],
                        "lemma": ["type": ["string","null"]],
                        "lexicalClass": ["type": ["string","null"], "description": "Part-of-speech tag (Noun/Verb/Adjective/...)"],
                    ],
                    "required": ["text"],
                ], description: "Per-token analysis; empty if tokens disabled"),
            ],
            required: ["tokens"]
        ))
    }

    public static var inputSchema: Value {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "text": ["type": "string", "description": "Text to analyze"],
                "includeTokens": ["type": "boolean", "description": "Return per-token lemma + lexicalClass (default true)"],
                "includeSentiment": ["type": "boolean", "description": "Compute sentiment score (default true)"],
            ],
            required: ["text"]
        ))
    }

    public static func call(arguments: [String: Value]) async throws -> Encodable & Sendable {
        let input = try ToolArgs.decode(Input.self, from: arguments)
        return NLAnalyze.run(
            text: input.text,
            includeTokens: input.includeTokens ?? true,
            includeSentiment: input.includeSentiment ?? true
        )
    }
}
