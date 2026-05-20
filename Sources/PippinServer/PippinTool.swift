import Foundation
import MCP
import PippinCore

public protocol PippinTool: Sendable {
    static var name: String { get }
    static var title: String { get }
    static var description: String { get }
    static var inputSchema: Value { get }
    static var outputSchema: Value? { get }
    static var annotations: Tool.Annotations { get }

    static func call(arguments: [String: Value]) async throws -> Encodable & Sendable
}

extension PippinTool {
    public static var outputSchema: Value? { nil }
    public static var annotations: Tool.Annotations {
        .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    }

    public static func toolDescriptor() -> Tool {
        Tool(
            name: name,
            title: title,
            description: description,
            inputSchema: inputSchema,
            annotations: annotations,
            outputSchema: outputSchema
        )
    }
}

public enum ToolArgs {
    /// Decode an MCP arguments object into a `Codable` input struct.
    public static func decode<T: Decodable>(_ type: T.Type, from arguments: [String: Value]?) throws -> T {
        let value = Value.object(arguments ?? [:])
        let data = try JSONEncoder().encode(value)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PippinError.invalidInput("could not decode arguments: \(error)")
        }
    }

    /// Convert a JSON Schema dictionary into MCP `Value`.
    public static func schema(_ dict: [String: Any]) -> Value {
        guard let value = try? JSONSerialization.data(withJSONObject: dict),
              let decoded = try? JSONDecoder().decode(Value.self, from: value)
        else {
            return .object([:])
        }
        return decoded
    }
}
