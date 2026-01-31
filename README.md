# GritGuard

Lightweight OS-level sandboxing for Claude Code CLI using Anthropic's Sandbox Runtime (srt).

## Features

- **Filesystem isolation**: Block access to sensitive directories (SSH keys, cloud credentials)
- **Network allowlisting**: Only permit connections to approved domains
- **Write restrictions**: Limit file modifications to specific directories
- **Cross-platform**: Uses `bubblewrap` on Linux, `sandbox-exec` on macOS

## Quick Start

```bash
# Install dependencies
./bin/setup.sh

# Copy and customize settings
cp templates/srt-settings.json ~/.srt-settings.json
# Edit to add your allowed domains and paths

# Run Claude Code in sandbox
./bin/claude-sandboxed
```

## Configuration

Edit `.srt-settings.json` in your project root or home directory:

```json
{
  "file_read_settings": {
    "policy": "allowlist",
    "paths": ["/home/user/.ssh", "/home/user/.aws"]
  },
  "file_write_settings": {
    "policy": "denylist",
    "paths": ["/home/user/myproject"]
  },
  "network_settings": {
    "policy": "allowlist",
    "domains": ["api.anthropic.com", "github.com", "registry.npmjs.org"]
  }
}
```

### Policies

| Setting | Policy | Meaning |
|---------|--------|---------|
| `file_read_settings` | `allowlist` | Block reading from listed paths (deny-read) |
| `file_write_settings` | `denylist` | Only allow writing to listed paths (allow-write) |
| `network_settings` | `allowlist` | Only allow connections to listed domains |

## Requirements

- Node.js 18+
- `@anthropic-ai/sandbox-runtime` npm package
- Linux: `bubblewrap` (`bwrap`), `socat`
- macOS: Built-in `sandbox-exec`

## Testing

```bash
# Full test suite (includes network tests)
./tests/test_sandbox.sh

# Quick tests (no network)
./tests/test_sandbox_quick.sh
```

## Integration

GritGuard can wrap any CLI tool. To use with other tools:

```bash
# Generic wrapper
srt --config .srt-settings.json -- your-command args
```

## License

MIT
