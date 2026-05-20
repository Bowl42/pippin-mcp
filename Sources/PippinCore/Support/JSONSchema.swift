import Foundation

/// Tiny helper to build JSON Schema as plain Foundation values.
/// We avoid pulling in a full schema lib — schemas are static per tool.
public enum JSONSchema {
    public static func object(
        properties: [String: Any],
        required: [String] = [],
        description: String? = nil
    ) -> [String: Any] {
        var s: [String: Any] = [
            "type": "object",
            "properties": properties,
        ]
        if !required.isEmpty { s["required"] = required }
        if let d = description { s["description"] = d }
        s["additionalProperties"] = false
        return s
    }

    public static func string(_ description: String, enumValues: [String]? = nil) -> [String: Any] {
        var s: [String: Any] = ["type": "string", "description": description]
        if let e = enumValues { s["enum"] = e }
        return s
    }

    public static func array(items: [String: Any], description: String) -> [String: Any] {
        ["type": "array", "items": items, "description": description]
    }

    public static func imageRef(_ description: String = "Image input: provide either a file path or base64-encoded data") -> [String: Any] {
        [
            "description": description,
            "oneOf": [
                ["type": "object", "properties": ["path": ["type": "string", "description": "Absolute file path"]], "required": ["path"], "additionalProperties": false],
                ["type": "object", "properties": ["base64": ["type": "string", "description": "Base64 data (data URL prefix optional)"]], "required": ["base64"], "additionalProperties": false],
            ],
        ]
    }
}
