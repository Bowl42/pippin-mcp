import Foundation
import MCP
import PippinCore

public struct PippinServer: Sendable {
    public let server: Server
    public let registry: ToolRegistry

    public init(registry: ToolRegistry) {
        self.server = Server(
            name: "pippin-mcp",
            version: PippinVersion.current,
            capabilities: .init(tools: .init(listChanged: false))
        )
        self.registry = registry
    }

    public func start(transport: any Transport) async throws {
        await wireHandlers()
        try await server.start(transport: transport)
    }

    public func waitUntilCompleted() async {
        await server.waitUntilCompleted()
    }

    private func wireHandlers() async {
        let reg = registry

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: reg.entries.map { $0.descriptor })
        }

        await server.withMethodHandler(CallTool.self) { params in
            guard let entry = reg.descriptor(named: params.name) else {
                return .init(content: [.text(text: "unknown tool: \(params.name)", annotations: nil, _meta: nil)], isError: true)
            }
            do {
                let result = try await entry.call(params.arguments ?? [:])
                let json = try jsonString(result)
                return try .init(
                    content: [.text(text: json, annotations: nil, _meta: nil)],
                    structuredContent: AnyCodable(result),
                    isError: false
                )
            } catch {
                return .init(
                    content: [.text(text: "\(error)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        }
    }
}

private func jsonString<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

/// Wraps an `Encodable` so it satisfies `Codable` for SDK APIs that require it.
/// We never decode it — only encode through it.
private struct AnyCodable: Codable {
    let value: any (Encodable & Sendable)
    init(_ value: any (Encodable & Sendable)) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
    init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "AnyCodable is write-only"))
    }
}

public enum PippinVersion {
    public static let current = "0.2.1"
}
