import Foundation
import MCP
import PippinCore

public enum ClassifyTool: PippinTool {
    public static let name = "vision_classify"
    public static let title = "Apple Vision Image Classification"
    public static let description = """
    Classify the dominant subjects in an image using Apple's on-device Vision \
    framework. Returns ranked labels with confidence (0..1). Runs entirely offline. \
    Use this to get a high-level idea of what an image contains (e.g. "dog", \
    "mountain", "document"). For text extraction use vision_ocr instead.
    """

    struct Input: Codable {
        let image: ImageRef
        let maxResults: Int?
        let minConfidence: Double?
    }

    public static var outputSchema: Value? {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "labels": JSONSchema.array(items: [
                    "type": "object",
                    "properties": [
                        "identifier": ["type": "string", "description": "Label identifier (e.g. 'document', 'dog')"],
                        "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                    ],
                    "required": ["identifier","confidence"],
                ], description: "Ranked classification labels, highest confidence first"),
            ],
            required: ["labels"]
        ))
    }

    public static var inputSchema: Value {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "image": JSONSchema.imageRef(),
                "maxResults": ["type": "integer", "description": "Max labels to return (default 10)", "minimum": 1, "maximum": 100],
                "minConfidence": ["type": "number", "description": "Minimum confidence 0..1 (default 0.1)", "minimum": 0, "maximum": 1],
            ],
            required: ["image"]
        ))
    }

    public static func call(arguments: [String: Value]) async throws -> Encodable & Sendable {
        let input = try ToolArgs.decode(Input.self, from: arguments)
        let image = try ImageLoader.load(input.image)
        return try await Classify.run(
            image: image,
            maxResults: input.maxResults ?? 10,
            minConfidence: input.minConfidence ?? 0.1
        )
    }
}
