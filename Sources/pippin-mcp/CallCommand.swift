import ArgumentParser
import Foundation
import MCP
import PippinServer

struct CallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "call",
        abstract: "Invoke a tool once and print the JSON result to stdout. Useful for testing without an MCP client."
    )

    @Argument(help: "Tool name (e.g. vision_ocr, nl_analyze, translate, fm_generate, vision_classify)")
    var tool: String

    @Option(name: .long, help: "Arguments as JSON object. Mutually exclusive with --stdin.")
    var json: String?

    @Flag(name: .long, help: "Read JSON arguments from stdin.")
    var stdin: Bool = false

    func run() async throws {
        let raw: String
        if stdin {
            raw = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? "{}"
        } else if let json {
            raw = json
        } else {
            raw = "{}"
        }
        guard let data = raw.data(using: .utf8),
              let args = try JSONDecoder().decode([String: Value].self, from: data) as [String: Value]?
        else {
            throw ValidationError("could not parse --json as a JSON object")
        }

        let registry = buildRegistry()
        guard let entry = registry.descriptor(named: tool) else {
            let available = registry.entries.map(\.descriptor.name).joined(separator: ", ")
            FileHandle.standardError.write(Data("unknown tool: \(tool)\navailable: \(available)\n".utf8))
            throw ExitCode.failure
        }

        do {
            let result = try await entry.call(args)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let out = try encoder.encode(AnyEncodable(result))
            FileHandle.standardOutput.write(out)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            throw ExitCode.failure
        }
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
