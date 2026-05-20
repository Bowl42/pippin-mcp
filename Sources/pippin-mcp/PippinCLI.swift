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

    @Option(name: .long, help: "HTTP bind host (default 127.0.0.1)")
    var host: String?

    @Option(name: .long, help: "HTTP bind port (default 1996)")
    var port: Int?

    @Option(name: .long, help: "Max request body in MB (default 256)")
    var maxBodyMb: Int?

    @Option(name: .long, help: "Require Bearer token for /mcp. Env: PIPPIN_TOKEN")
    var authToken: String?

    @Flag(name: .long, help: "Disable localhost-only origin check. Use with --host 0.0.0.0.")
    var bindPublic: Bool = false

    @Option(name: .long, help: "Path to config.json (defaults: /opt/homebrew/etc/pippin-mcp/config.json, /usr/local/etc/pippin-mcp/config.json)")
    var config: String?

    func run() async throws {
        switch transport {
        case .stdio:
            let pippin = PippinServer(registry: buildRegistry())
            let t = StdioTransport()
            try await pippin.start(transport: t)
            await pippin.waitUntilCompleted()
        case .http:
            let resolved = ConfigLoader.resolve(
                cliOverrides: ServeConfig(
                    host: host,
                    port: port,
                    maxBodyMb: maxBodyMb,
                    authToken: authToken
                ),
                bindPublicCLI: bindPublic,
                explicitConfigPath: config
            )
            let cfg = HTTPConfig(
                host: resolved.host,
                port: resolved.port,
                maxBodyMB: resolved.maxBodyMb,
                authToken: resolved.authToken,
                bindPublic: resolved.bindPublic
            )
            try await HTTPTransportRunner(config: cfg, configFileLoaded: resolved.configFileLoaded).run()
        }
    }
}
