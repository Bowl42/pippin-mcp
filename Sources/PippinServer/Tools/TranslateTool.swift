import Foundation
import MCP
import PippinCore

public enum TranslateTool: PippinTool {
    public static let name = "translate"
    public static let title = "On-device Translation"
    public static let description = """
    Translate text between languages using Apple's on-device Translation framework. \
    Both source and target languages are required (BCP-47 tags, e.g. "en", "zh-Hans", "ja"). \
    First use of a language pair may require the system to download the language pack — \
    this can fail in headless contexts where the OS cannot prompt the user. \
    No data leaves the device once language packs are installed.
    """

    struct Input: Codable {
        let text: String
        let sourceLanguage: String
        let targetLanguage: String
    }

    public static var outputSchema: Value? {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "sourceLanguage": ["type": "string", "description": "Echo of input source language"],
                "targetLanguage": ["type": "string", "description": "Echo of input target language"],
                "translatedText": ["type": "string", "description": "Translated text"],
            ],
            required: ["sourceLanguage","targetLanguage","translatedText"]
        ))
    }

    public static var inputSchema: Value {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "text": ["type": "string", "description": "Text to translate"],
                "sourceLanguage": ["type": "string", "description": "BCP-47 source language tag (e.g. 'en', 'zh-Hans')"],
                "targetLanguage": ["type": "string", "description": "BCP-47 target language tag"],
            ],
            required: ["text", "sourceLanguage", "targetLanguage"]
        ))
    }

    public static func call(arguments: [String: Value]) async throws -> Encodable & Sendable {
        let input = try ToolArgs.decode(Input.self, from: arguments)
        return try await Translate.run(
            text: input.text,
            sourceLanguage: input.sourceLanguage,
            targetLanguage: input.targetLanguage
        )
    }
}
