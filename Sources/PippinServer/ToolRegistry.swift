import Foundation
import MCP

public struct ToolRegistry: Sendable {
    public typealias Caller = @Sendable ([String: Value]) async throws -> any (Encodable & Sendable)

    public struct Entry: Sendable {
        public let descriptor: Tool
        public let call: Caller
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public func descriptor(named name: String) -> Entry? {
        entries.first { $0.descriptor.name == name }
    }

    public static func register<T: PippinTool>(_ tool: T.Type) -> Entry {
        Entry(
            descriptor: T.toolDescriptor(),
            call: { args in try await T.call(arguments: args) }
        )
    }
}
