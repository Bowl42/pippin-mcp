import Foundation
import HTTPTypes
import Hummingbird
import Logging
import MCP
import NIOCore
import PippinServer

struct HTTPConfig {
    var host: String
    var port: Int
    var maxBodyMB: Int
    var authToken: String?
    var bindPublic: Bool
}

/// Bridges Hummingbird HTTP requests to MCP `StatelessHTTPServerTransport`.
///
/// POST /mcp  — JSON-RPC request/response
/// GET/DELETE /mcp — 405 Method Not Allowed (stateless: no SSE, no sessions)
struct HTTPTransportRunner {
    let config: HTTPConfig

    func run() async throws {
        let validators: [any HTTPRequestValidator] = [
            config.bindPublic ? OriginValidator.disabled : OriginValidator.localhost(port: config.port),
            AcceptHeaderValidator(mode: .jsonOnly),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
        ]
        let transport = StatelessHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: validators)
        )
        let pippin = PippinServer(registry: buildRegistry())

        Task {
            try await pippin.start(transport: transport)
            await pippin.waitUntilCompleted()
        }

        let maxBytes = config.maxBodyMB * 1024 * 1024
        let token = config.authToken
        let router = Router()

        router.add(middleware: LogRequestsMiddleware(.info))
        if let token, !token.isEmpty {
            router.add(middleware: BearerAuthMiddleware(token: token, skipPaths: ["/healthz"]))
        }

        router.post("/mcp") { request, context -> Response in
            await Self.handle(request: request, maxBytes: maxBytes, transport: transport)
        }
        router.on("/mcp", method: .get) { _, _ in Response(status: .methodNotAllowed) }
        router.on("/mcp", method: .delete) { _, _ in Response(status: .methodNotAllowed) }
        router.get("/healthz") { _, _ in Response(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "ok"))) }

        let skillToken = token
        router.get("/skill.md") { request, _ -> Response in
            Self.renderSkill(request: request, authToken: skillToken)
        }
        router.get("/skill") { request, _ -> Response in
            Self.renderSkill(request: request, authToken: skillToken)
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname(config.host, port: config.port), serverName: "pippin-mcp")
        )
        let banner = "pippin-mcp listening on http://\(config.host):\(config.port)/mcp"
            + (token != nil && !token!.isEmpty ? " (auth: Bearer required)" : " (no auth)")
            + (config.bindPublic ? " [public-bind, origin check disabled]" : "")
        FileHandle.standardError.write(Data("\(banner)\n".utf8))
        try await app.runService()
    }

    private static func handle(request: Request, maxBytes: Int, transport: StatelessHTTPServerTransport) async -> Response {
        var headers: [String: String] = [:]
        for field in request.headers {
            headers[field.name.canonicalName] = field.value
        }
        let bodyData: Data
        do {
            let buf = try await request.body.collect(upTo: maxBytes)
            bodyData = Data(buffer: buf)
        } catch {
            return Response(status: .contentTooLarge)
        }

        let mcpReq = MCP.HTTPRequest(
            method: request.method.rawValue,
            headers: headers,
            body: bodyData,
            path: request.uri.path
        )
        let mcpRes = await transport.handleRequest(mcpReq)
        return makeResponse(from: mcpRes)
    }

    private static func renderSkill(request: Request, authToken: String?) -> Response {
        let host: String
        if let auth = request.head.authority, !auth.isEmpty {
            host = auth
        } else if let h = request.headers.first(where: { $0.name.canonicalName.lowercased() == "host" })?.value, !h.isEmpty {
            host = h
        } else {
            host = "127.0.0.1"
        }
        let baseURL = "http://\(host)"
        let md = SkillRenderer.render(
            registry: buildRegistry(),
            baseURL: baseURL,
            skillName: "pippin-mcp",
            authToken: authToken
        )
        var headers = HTTPFields()
        headers.append(HTTPField(name: .contentType, value: "text/markdown; charset=utf-8"))
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: md)))
    }

    private static func makeResponse(from r: MCP.HTTPResponse) -> Response {
        var headers = HTTPFields()
        for (k, v) in r.headers {
            if let name = HTTPField.Name(k) {
                headers.append(HTTPField(name: name, value: v))
            }
        }
        let status = HTTPResponse.Status(code: r.statusCode)
        switch r {
        case .stream:
            return Response(status: status, headers: headers)
        default:
            let data = r.bodyData ?? Data()
            return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(data: data)))
        }
    }
}

/// Shared-secret Bearer auth. Constant-time comparison.
struct BearerAuthMiddleware<Context: Hummingbird.RequestContext>: RouterMiddleware {
    let token: String
    let skipPaths: Set<String>

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        if skipPaths.contains(request.uri.path) {
            return try await next(request, context)
        }
        guard let header = request.headers[.authorization],
              let provided = parseBearer(header),
              constantTimeEqual(provided, token)
        else {
            var headers = HTTPFields()
            headers.append(HTTPField(name: .wwwAuthenticate, value: "Bearer realm=\"pippin-mcp\""))
            return Response(status: .unauthorized, headers: headers)
        }
        return try await next(request, context)
    }

    private func parseBearer(_ value: String) -> String? {
        let prefix = "Bearer "
        guard value.hasPrefix(prefix) else { return nil }
        return String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let ab = Array(a.utf8), bb = Array(b.utf8)
        guard ab.count == bb.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<ab.count { diff |= ab[i] ^ bb[i] }
        return diff == 0
    }
}
