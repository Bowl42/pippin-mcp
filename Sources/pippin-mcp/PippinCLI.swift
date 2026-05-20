import ArgumentParser
import Foundation
import MCP
import PippinServer

@main
struct PippinCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pippin-mcp",
        abstract: "MCP server exposing Apple on-device AI capabilities (Vision, NaturalLanguage, Translation, Foundation Models).",
        version: PippinVersion.current,
        subcommands: [ServeCommand.self, CallCommand.self, DoctorCommand.self, SkillCommand.self],
        defaultSubcommand: ServeCommand.self
    )
}

struct ServeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the MCP server (default: stdio transport)."
    )

    enum TransportKind: String, ExpressibleByArgument {
        case stdio, http
    }

    @Option(name: .long, help: "Transport: stdio (default) or http")
    var transport: TransportKind = .stdio

    @Option(name: .long, help: "HTTP bind host (http only)")
    var host: String = "127.0.0.1"

    @Option(name: .long, help: "HTTP bind port (http only)")
    var port: Int = 1996

    @Option(name: .long, help: "Max request body in MB (http only)")
    var maxBodyMb: Int = 256

    @Option(name: .long, help: "Require Bearer token for all routes except /healthz. Env: PIPPIN_TOKEN")
    var authToken: String?

    @Flag(name: .long, help: "Disable localhost-only origin check (allow public binding). Use with --host 0.0.0.0.")
    var bindPublic: Bool = false

    func run() async throws {
        switch transport {
        case .stdio:
            let pippin = PippinServer(registry: buildRegistry())
            let t = StdioTransport()
            try await pippin.start(transport: t)
            await pippin.waitUntilCompleted()
        case .http:
            let token = authToken ?? ProcessInfo.processInfo.environment["PIPPIN_TOKEN"]
            let cfg = HTTPConfig(
                host: host,
                port: port,
                maxBodyMB: maxBodyMb,
                authToken: token,
                bindPublic: bindPublic
            )
            try await HTTPTransportRunner(config: cfg).run()
        }
    }
}
