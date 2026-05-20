import Foundation

/// Layered HTTP-serve configuration. Precedence: CLI flag > env var > config file > built-in default.
public struct ServeConfig: Codable, Sendable {
    public var host: String?
    public var port: Int?
    public var maxBodyMb: Int?
    public var authToken: String?
    public var bindPublic: Bool?

    public init(host: String? = nil, port: Int? = nil, maxBodyMb: Int? = nil, authToken: String? = nil, bindPublic: Bool? = nil) {
        self.host = host
        self.port = port
        self.maxBodyMb = maxBodyMb
        self.authToken = authToken
        self.bindPublic = bindPublic
    }

    public static let defaultCandidates = [
        "/opt/homebrew/etc/pippin-mcp/config.json",  // Apple Silicon brew
        "/usr/local/etc/pippin-mcp/config.json",      // Intel brew
    ]
}

public struct ResolvedConfig: Sendable {
    public let host: String
    public let port: Int
    public let maxBodyMb: Int
    public let authToken: String?
    public let bindPublic: Bool
    public let configFileLoaded: String?
}

public enum ConfigLoader {
    /// Resolve final values by layering file < env < CLI overrides.
    /// `cliOverrides` should contain only values the user explicitly set on the command line;
    /// pass `nil` (or `false` for flags) for "not provided".
    public static func resolve(
        cliOverrides: ServeConfig,
        bindPublicCLI: Bool,
        explicitConfigPath: String?
    ) -> ResolvedConfig {
        let (file, loadedPath) = loadFile(explicit: explicitConfigPath)
        let env = loadEnv()

        return ResolvedConfig(
            host: cliOverrides.host ?? env.host ?? file.host ?? "127.0.0.1",
            port: cliOverrides.port ?? env.port ?? file.port ?? 1996,
            maxBodyMb: cliOverrides.maxBodyMb ?? env.maxBodyMb ?? file.maxBodyMb ?? 256,
            authToken: nonEmpty(cliOverrides.authToken) ?? nonEmpty(env.authToken) ?? nonEmpty(file.authToken),
            bindPublic: bindPublicCLI || (env.bindPublic ?? file.bindPublic ?? false),
            configFileLoaded: loadedPath
        )
    }

    public static func loadFile(explicit: String?) -> (ServeConfig, String?) {
        let candidates: [String]
        if let explicit { candidates = [explicit] }
        else if let env = ProcessInfo.processInfo.environment["PIPPIN_CONFIG"], !env.isEmpty {
            candidates = [env]
        } else {
            candidates = ServeConfig.defaultCandidates
        }
        for path in candidates {
            let expanded = (path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: expanded)) else { continue }
            guard let decoded = try? JSONDecoder().decode(ServeConfig.self, from: data) else { continue }
            return (decoded, expanded)
        }
        return (ServeConfig(), nil)
    }

    public static func loadEnv() -> ServeConfig {
        let env = ProcessInfo.processInfo.environment
        return ServeConfig(
            host: nonEmpty(env["PIPPIN_HOST"]),
            port: env["PIPPIN_PORT"].flatMap(Int.init),
            maxBodyMb: env["PIPPIN_MAX_BODY_MB"].flatMap(Int.init),
            authToken: nonEmpty(env["PIPPIN_TOKEN"]),
            bindPublic: env["PIPPIN_BIND_PUBLIC"].map(parseBool)
        )
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }

    private static func parseBool(_ s: String) -> Bool {
        ["1", "true", "yes", "on"].contains(s.lowercased())
    }
}
