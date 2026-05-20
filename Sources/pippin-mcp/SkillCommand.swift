import ArgumentParser
import Foundation
import MCP
import PippinServer

struct SkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Generate a Claude Code SKILL.md that teaches how to call this server over HTTP."
    )

    @Option(name: .long, help: "Base URL of the running pippin-mcp HTTP server (e.g. http://127.0.0.1:1996)")
    var baseURL: String

    @Option(name: .shortAndLong, help: "Output path (default: stdout)")
    var output: String?

    @Option(name: .long, help: "Skill name used in frontmatter")
    var name: String = "pippin-mcp"

    @Option(name: .long, help: "If set, the skill will embed this Bearer token in all examples. Omit if the server runs without auth.")
    var authToken: String?

    func run() async throws {
        let registry = buildRegistry()
        let url = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let md = SkillRenderer.render(registry: registry, baseURL: url, skillName: name, authToken: authToken)
        if let output {
            let url = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try md.data(using: .utf8)?.write(to: url)
            FileHandle.standardError.write(Data("wrote \(url.path)\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data(md.utf8))
        }
    }
}

enum SkillRenderer {
    static func render(registry: ToolRegistry, baseURL: String, skillName: String, authToken: String?) -> String {
        var lines: [String] = []

        let toolNames = registry.entries.map { $0.descriptor.name }.joined(separator: ", ")
        let authHeaderLine = authToken.map { "Authorization: Bearer \($0)" }
        let curlAuthFlag = authToken.map { "  -H 'Authorization: Bearer \($0)' \\\n" } ?? ""
        let authSection: String
        if authHeaderLine != nil {
            authSection = """

            **Authentication is required.** Every request to `/mcp` MUST include the
            Authorization header below. `/healthz` is unauthenticated.

            """
        } else {
            authSection = "\nThis server is configured **without authentication** — any LAN client can reach it.\n"
        }

        let headersBlock = (["Content-Type: application/json",
                             "Accept: application/json",
                             "MCP-Protocol-Version: 2025-11-25"]
                            + (authHeaderLine.map { [$0] } ?? []))
            .joined(separator: "\n")

        lines.append("""
        ---
        name: \(skillName)
        description: Call Apple's on-device AI capabilities (Vision OCR / image classification / NaturalLanguage / Translation / Foundation Models) via a self-hosted pippin-mcp HTTP server. Use when you need offline OCR, image labels, language detection + sentiment, text translation, or on-device LLM generation. Tools available: \(toolNames).
        ---

        # pippin-mcp

        This skill teaches you to call a self-hosted **pippin-mcp** server over HTTP.
        The server exposes Apple's on-device AI as MCP tools — everything runs on the
        host machine; no data leaves the device.

        ## Endpoint

        Base URL: `\(baseURL)`

        - `POST \(baseURL)/mcp` — JSON-RPC 2.0 request/response
        - `GET  \(baseURL)/healthz` — liveness check (returns `ok`)
        \(authSection)
        Required request headers:

        ```
        \(headersBlock)
        ```

        ## Calling a tool

        All tool calls use the same JSON-RPC envelope:

        ```bash
        curl -s -X POST \(baseURL)/mcp \\
        \(curlAuthFlag)  -H 'Content-Type: application/json' \\
          -H 'Accept: application/json' \\
          -H 'MCP-Protocol-Version: 2025-11-25' \\
          -d '{
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
              "name": "<tool-name>",
              "arguments": { ... }
            }
          }'
        ```

        The response contains `result.structuredContent` with the typed payload and
        `result.content[0].text` with the JSON-stringified version. Prefer
        `structuredContent` when parsing.

        On error: `result.isError == true` and the message is in `result.content[0].text`.

        ## Available tools

        """)

        for entry in registry.entries {
            lines.append(renderTool(entry, baseURL: baseURL, curlAuthFlag: curlAuthFlag))
        }

        lines.append("""
        ## Listing tools at runtime

        To re-discover the live tool list (in case the server adds tools):

        ```bash
        curl -s -X POST \(baseURL)/mcp \\
        \(curlAuthFlag)  -H 'Content-Type: application/json' \\
          -H 'Accept: application/json' \\
          -H 'MCP-Protocol-Version: 2025-11-25' \\
          -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
        ```
        """)

        return lines.joined(separator: "\n")
    }

    private static func renderTool(_ entry: ToolRegistry.Entry, baseURL: String, curlAuthFlag: String) -> String {
        let d = entry.descriptor
        let title = d.title ?? d.name
        let description = d.description ?? ""

        let exampleArgs = exampleArguments(for: d.name)
        let exampleJSON = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "method": "tools/call",
          "params": {
            "name": "\(d.name)",
            "arguments": \(indent(exampleArgs, by: 4))
          }
        }
        """

        let inputSchemaJSON = (try? prettyJSON(d.inputSchema)) ?? "{}"
        let outputSection: String
        if let out = d.outputSchema, let outJSON = try? prettyJSON(out) {
            outputSection = """
            **Output schema** (shape of `result.structuredContent`):

            ```json
            \(outJSON)
            ```

            """
        } else {
            outputSection = ""
        }

        return """
        ### `\(d.name)` — \(title)

        \(description)

        **Input schema:**

        ```json
        \(inputSchemaJSON)
        ```

        \(outputSection)**Example:**

        ```bash
        curl -s -X POST \(baseURL)/mcp \\
        \(curlAuthFlag)  -H 'Content-Type: application/json' \\
          -H 'Accept: application/json' \\
          -H 'MCP-Protocol-Version: 2025-11-25' \\
          -d '\(exampleJSON.replacingOccurrences(of: "\n", with: "\n     "))'
        ```

        """
    }

    private static func exampleArguments(for tool: String) -> String {
        switch tool {
        case "vision_ocr":
            return #"{"image":{"path":"/absolute/path/to/image.png"},"languages":["zh-Hans","en-US"]}"#
        case "vision_classify":
            return #"{"image":{"path":"/absolute/path/to/image.png"},"maxResults":5}"#
        case "nl_analyze":
            return #"{"text":"This new product is amazing!"}"#
        case "translate":
            return #"{"text":"Hello, world!","sourceLanguage":"en","targetLanguage":"zh-Hans"}"#
        case "fm_generate":
            return #"{"prompt":"Summarize on-device AI in one sentence.","temperature":0.3}"#
        default:
            return "{}"
        }
    }

    private static func prettyJSON(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func indent(_ s: String, by spaces: Int) -> String {
        let pad = String(repeating: " ", count: spaces)
        return s.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { i, line in i == 0 ? String(line) : pad + line }
            .joined(separator: "\n")
    }
}
