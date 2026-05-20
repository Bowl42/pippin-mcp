import Foundation
import MCP
import PippinCore

public enum FMGenerateTool: PippinTool {
    public static let name = "fm_generate"
    public static let title = "Foundation Models (Apple Intelligence)"
    public static let description = """
    Generate text with Apple's on-device foundation model (Apple Intelligence). \
    Requires macOS 26+, Apple Silicon, and Apple Intelligence enabled in System Settings. \
    Use this for tasks that benefit from running fully on-device with no network: \
    classification, short summarization, structured extraction from short text. \
    The on-device model is ~3B params — prefer cloud models for long-form reasoning.
    """

    struct Input: Codable {
        let prompt: String
        let instructions: String?
        let temperature: Double?
    }

    public static var outputSchema: Value? {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "text": ["type": "string", "description": "Generated text"],
            ],
            required: ["text"]
        ))
    }

    public static var inputSchema: Value {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "prompt": ["type": "string", "description": "User prompt"],
                "instructions": ["type": "string", "description": "Optional system instructions"],
                "temperature": ["type": "number", "description": "Sampling temperature (default model-defined)", "minimum": 0, "maximum": 2],
            ],
            required: ["prompt"]
        ))
    }

    public static func call(arguments: [String: Value]) async throws -> Encodable & Sendable {
        let input = try ToolArgs.decode(Input.self, from: arguments)
        return try await FMGenerate.run(
            prompt: input.prompt,
            instructions: input.instructions,
            temperature: input.temperature
        )
    }
}
