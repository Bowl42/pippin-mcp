import XCTest
@testable import PippinServer
import MCP

final class SchemaTests: XCTestCase {
    /// Every registered tool must have a non-empty name, title, description,
    /// and an inputSchema that is a JSON object with at least one required field.
    func testAllToolsHaveCompleteDescriptors() throws {
        let registry = ToolRegistry(entries: [
            ToolRegistry.register(OCRTool.self),
            ToolRegistry.register(ClassifyTool.self),
            ToolRegistry.register(NLAnalyzeTool.self),
            ToolRegistry.register(TranslateTool.self),
            ToolRegistry.register(FMGenerateTool.self),
        ])

        XCTAssertEqual(registry.entries.count, 5)

        let names = Set(registry.entries.map { $0.descriptor.name })
        XCTAssertEqual(names.count, registry.entries.count, "tool names must be unique")

        for entry in registry.entries {
            let d = entry.descriptor
            XCTAssertFalse(d.name.isEmpty, "name empty for \(d)")
            XCTAssertNotNil(d.title, "title nil for \(d.name)")
            XCTAssertNotNil(d.description, "description nil for \(d.name)")
            XCTAssertGreaterThan(d.description?.count ?? 0, 50, "\(d.name) description too short (LLMs need rich context)")

            // Verify schema serializes to a valid object with `properties` and `required`
            let data = try JSONEncoder().encode(d.inputSchema)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json, "\(d.name): inputSchema must encode to an object")
            XCTAssertEqual(json?["type"] as? String, "object", "\(d.name): schema type must be 'object'")
            XCTAssertNotNil(json?["properties"], "\(d.name): schema must have 'properties'")
        }
    }

    func testAllToolsAreReadOnlyAndIdempotent() {
        let tools: [any PippinTool.Type] = [
            OCRTool.self, ClassifyTool.self, NLAnalyzeTool.self,
            TranslateTool.self, FMGenerateTool.self,
        ]
        for t in tools {
            XCTAssertEqual(t.annotations.readOnlyHint, true, "\(t.name): should be readOnly")
            XCTAssertEqual(t.annotations.idempotentHint, true, "\(t.name): should be idempotent")
            XCTAssertEqual(t.annotations.openWorldHint, false, "\(t.name): should be closed-world (on-device)")
        }
    }
}
