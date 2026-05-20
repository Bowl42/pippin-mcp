# pippin-mcp

> Apple's on-device AI capabilities, exposed as an [MCP](https://modelcontextprotocol.io) server.

Named after **[Apple Pippin](https://en.wikipedia.org/wiki/Apple_Pippin)** — the first time Apple opened up its platform to third parties. `pippin-mcp` does the same for Apple's modern on-device AI: Vision, NaturalLanguage, Translation, and Foundation Models, callable from any MCP client.

Everything runs **entirely on-device**. No network calls, no API keys.

## Tools

| Name | What it does | Notes |
|---|---|---|
| `vision_ocr` | Multi-language OCR via Apple Vision | macOS 12+ |
| `vision_classify` | Image classification (ranked labels) | macOS 12+ |
| `nl_analyze` | Language ID + sentiment + tokenization | macOS 12+ |
| `translate` | Text translation via Apple Translation | Requires language pack pre-install |
| `fm_generate` | Text generation via Apple Intelligence (~3B on-device LLM) | macOS 26+, Apple Silicon, Apple Intelligence enabled, supported region |

Run `pippin-mcp doctor` to see what's available on your machine.

## Requirements

- macOS 26+ (Sequoia successor)
- Apple Silicon recommended (M-series)
- Swift 6.2+ toolchain to build from source

## Install

### Homebrew (recommended)

```bash
brew tap Bowl42/tap
brew install pippin-mcp
```

### From source

```bash
git clone https://github.com/Bowl42/pippin-mcp.git
cd pippin-mcp
swift build -c release
cp .build/release/pippin-mcp /usr/local/bin/   # or any dir on $PATH
```

There are no signed prebuilt binaries yet — Homebrew builds from source locally.

## Use with an MCP client

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "pippin": {
      "command": "/usr/local/bin/pippin-mcp",
      "args": ["serve"]
    }
  }
}
```

### Cursor / Cline / others

Same shape — point them at the `pippin-mcp serve` command over stdio.

### HTTP transport

```bash
pippin-mcp serve --transport http --host 127.0.0.1 --port 1996
```

POST JSON-RPC to `http://127.0.0.1:1996/mcp` with headers `Content-Type: application/json`, `Accept: application/json`, `MCP-Protocol-Version: 2025-11-25`. `GET /healthz` returns `ok`. Origin is restricted to localhost by default for safety. Streaming (SSE) is not yet supported — use stdio if you need streamed responses from `fm_generate`.

Production flags:

```bash
pippin-mcp serve --transport http \
  --host 0.0.0.0 --port 1996 \
  --bind-public \
  --auth-token "$(openssl rand -hex 32)" \
  --max-body-mb 256
```

- `--auth-token` (or env `PIPPIN_TOKEN`): require `Authorization: Bearer <token>` on `/mcp`. `/healthz` is always public.
- `--bind-public`: disable the default localhost-only origin check. Pair with `--host 0.0.0.0` to accept remote connections.
- `--max-body-mb`: max request body size (default 256 MB). Larger payloads return 413.
- All requests are logged at info level to stderr.

## Use from the CLI (no MCP client)

```bash
# Inspect capabilities
pippin-mcp doctor

# Call a tool directly, JSON in → JSON out
pippin-mcp call vision_ocr --json '{"image":{"path":"/tmp/screen.png"}}'
pippin-mcp call nl_analyze --json '{"text":"Apple Intelligence rocks."}'
pippin-mcp call translate  --json '{"text":"hello","sourceLanguage":"en","targetLanguage":"zh-Hans"}'
pippin-mcp call fm_generate --json '{"prompt":"Summarize on-device AI in one sentence."}'

# Or read args from stdin
echo '{"text":"hello"}' | pippin-mcp call nl_analyze --stdin
```

## Generate a Claude Code skill

Once you have an HTTP server running, generate a `SKILL.md` that teaches any LLM
agent (Claude Code, Cursor, etc.) how to POST JSON-RPC to it:

```bash
pippin-mcp skill --base-url http://your-server:1996 \
  -o ~/.claude/skills/pippin-mcp/SKILL.md
```

The skill content is generated from the live tool registry — new tools appear
automatically. Each tool gets its name, description, JSON Schema, and a working
`curl` example.

## Input formats

Tools that take images accept either form:

```json
{"image": {"path": "/absolute/path/to/file.png"}}
{"image": {"base64": "iVBORw0KGgo..."}}   // raw base64 or data: URL
```

## Setup notes

### Foundation Models (`fm_generate`)

Requires Apple Intelligence to be enabled:

1. System Settings → **Apple Intelligence & Siri**
2. Toggle Apple Intelligence on (first time downloads ~3GB)
3. Re-run `pippin-mcp doctor` to verify

Apple Intelligence has region restrictions. In some regions (e.g. mainland China as of late 2025/early 2026) availability is limited; you may need to change the system region in **Settings → General → Language & Region → Region**.

### Translation (`translate`)

The Translation framework downloads language packs on demand, but the prompt only appears in foreground GUI apps — not in a stdio MCP subprocess. **Install language pairs once via the system Translate app**, then `translate` works headlessly.

## Architecture

```
PippinCore      Pure Apple-framework wrappers (Vision/NL/Translation/FM).
                No MCP dependency — reusable as a Swift library or CLI.
PippinServer    MCP adapter: PippinTool protocol, ToolRegistry, Server wiring.
pippin-mcp      Thin CLI: serve / call / doctor.
```

Add a tool: implement the capability in `PippinCore`, write a `*Tool.swift` in `PippinServer/Tools`, register in `Sources/pippin-mcp/Registry.swift`.

## License

MIT
