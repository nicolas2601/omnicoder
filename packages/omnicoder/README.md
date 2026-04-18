# @omnicoder/core

OmniCoder v5 core plugin for Opencode. Bundles skill routing, security guard, memory layer, token budget, tool dispatcher and provider failover as a single drop-in plugin.

## Install

Add to your `opencode.jsonc`:

```jsonc
{
  "plugin": ["@omnicoder/core"],
  "skills": {
    "paths": ["~/.omnicoder/skills"]
  },
  "mcp": {
    "engram": {
      "type": "local",
      "command": ["engram", "mcp"],
      "enabled": true
    }
  }
}
```

## Hooks registered

| Hook event | Module | Responsibility |
|---|---|---|
| `experimental.chat.system.transform` | router, memory | Inject skill/agent suggestions + Engram memory into system prompt |
| `tool.execute.before` | security | Block dangerous bash commands, path traversal, secrets |
| `tool.execute.after` | dispatcher | Log tool usage, feed learning, detect patterns |
| `chat.params` | failover | Switch provider on rate-limit / 5xx |
| `event` | budget, dispatcher | Track tokens, alert on > 15k avg |

## Architecture

See `/docs/ADR-001` through `/docs/ADR-005` in the repo root for rationale.

## Acknowledgements

OmniCoder is a derivative work of **[Opencode](https://github.com/sst/opencode)** by SST (MIT).
All core runtime, TUI, plugin framework and MCP client are Opencode's. This package only adds
the OmniCoder-specific plugin glue, skill routing, security guard, memory layer and budget
tracking. See `NOTICE` for full attribution.

## License

MIT — see `LICENSE` in the repository root.
