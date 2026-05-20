import Foundation
import MCP
import PippinCore

public enum OCRTool: PippinTool {
    public static let name = "vision_ocr"
    public static let title = "Apple Vision OCR"
    public static let description = """
    Recognize text in an image using Apple's on-device Vision framework. \
    Supports multiple languages simultaneously (e.g. ["zh-Hans", "en-US"]) and \
    returns recognized text along with per-block bounding boxes and confidence. \
    Runs entirely offline; no data leaves the device. \
    Use this for screenshots, scanned documents, photos of text. \
    For barcodes use vision_detect_barcodes (not yet available); for object \
    classification use vision_classify.
    """

    struct Input: Codable {
        let image: ImageRef
        let languages: [String]?
        let level: OCRLevel?
        let usesLanguageCorrection: Bool?
    }

    public static var outputSchema: Value? {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "text": ["type": "string", "description": "Recognized text, lines joined by '\\n'"],
                "detectedLanguages": JSONSchema.array(items: ["type": "string"], description: "Languages used for recognition (echoes input)"),
                "blocks": JSONSchema.array(items: [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string"],
                        "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                        "boundingBox": [
                            "type": "object",
                            "properties": [
                                "x": ["type": "number"], "y": ["type": "number"],
                                "width": ["type": "number"], "height": ["type": "number"],
                            ],
                            "required": ["x","y","width","height"],
                        ],
                    ],
                    "required": ["text","confidence","boundingBox"],
                ], description: "Per-line recognition blocks (normalized coords 0..1, origin bottom-left)"),
            ],
            required: ["text","blocks","detectedLanguages"]
        ))
    }

    public static var inputSchema: Value {
        ToolArgs.schema(JSONSchema.object(
            properties: [
                "image": JSONSchema.imageRef(),
                "languages": JSONSchema.array(
                    items: ["type": "string"],
                    description: "BCP-47 language tags to recognize (e.g. ['zh-Hans','en-US']). Omit to auto-detect."
                ),
                "level": JSONSchema.string("Recognition level — 'accurate' (default) or 'fast'", enumValues: ["accurate", "fast"]),
                "usesLanguageCorrection": ["type": "boolean", "description": "Apply language-model correction (default true)"],
            ],
            required: ["image"]
        ))
    }

    public static func call(arguments: [String: Value]) async throws -> Encodable & Sendable {
        let input = try ToolArgs.decode(Input.self, from: arguments)
        let image = try ImageLoader.load(input.image)
        return try await OCR.recognize(
            image: image,
            languages: input.languages ?? [],
            level: input.level ?? .accurate,
            usesLanguageCorrection: input.usesLanguageCorrection ?? true
        )
    }
}
