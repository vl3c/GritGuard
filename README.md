# GritGuard

Lightweight OS-level sandboxing for AI agents and autonomous applications.

## Features

- **Filesystem isolation**: Block access to sensitive directories (SSH keys, cloud credentials)
- **Network allowlisting**: Only permit connections to approved domains
- **Write restrictions**: Limit file modifications to specific directories
- **Dynamic config**: Automatically configures write paths for target project
- **Cross-platform**: Uses `bubblewrap` on Linux, `sandbox-exec` on macOS

## Quick Start

```bash
# Install dependencies
./bin/setup.sh

# Run any command in sandbox with dynamic config
./bin/gritguard your-command [args...]

# Example: Run SelfAssembler on a project
./bin/gritguard selfassembler "Add feature" --repo /path/to/project
```

## Usage

### Dynamic Mode (Recommended)

The `gritguard` wrapper automatically generates sandbox config based on the target directory:

```bash
# Sandbox a command with auto-detected paths
gritguard <command> [args...]

# Explicitly specify target directory
gritguard selfassembler "task" --repo /path/to/project

# Enable debug output
GRITGUARD_DEBUG=1 gritguard your-command
```

Dynamic mode automatically allows writes to:
- Target directory (the project being worked on)
- `<target>/.worktrees` and `<target>/../.worktrees`
- `<target>/logs`
- `<target>/plans`
- `/tmp`

### Static Mode

For fixed configurations, use the `sandboxed` wrapper:

```bash
# Uses .srt-settings.json in current directory
./bin/sandboxed your-command [args...]

# Or specify settings file
GRITGUARD_SETTINGS=/path/to/config.json ./bin/sandboxed your-command
```

## Configuration

### Base Template

Edit `templates/base.json` for network and read restrictions:

```json
{
  "file_read_settings": {
    "policy": "allowlist",
    "paths": ["/home/user/.ssh", "/home/user/.aws"]
  },
  "file_write_settings": {
    "policy": "denylist",
    "paths": []
  },
  "network_settings": {
    "policy": "allowlist",
    "domains": ["api.anthropic.com", "api.openai.com", "github.com"]
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
- `jq` (for config generation)
- Linux: `bubblewrap` (`bwrap`), `socat`
- macOS: Built-in `sandbox-exec`

## Testing

```bash
# Full test suite (includes network tests)
./tests/test_sandbox.sh

# Quick tests (no network)
./tests/test_sandbox_quick.sh
```

## Use Cases

- **AI Coding Agents**: Prevent agents from accessing credentials or modifying system files
- **Autonomous Workflows**: Limit blast radius of automated processes
- **Development Sandboxes**: Isolate experimental code execution
- **CI/CD Pipelines**: Secure build and test environments

## How It Works

```
gritguard selfassembler "task" --repo /path/to/project
    │
    ├── 1. Parse command to find target directory
    │
    ├── 2. Generate dynamic config (templates/base.json + write paths)
    │
    ├── 3. Run: srt --settings <temp-config> "selfassembler task --repo ..."
    │
    └── 4. Cleanup temp config on exit
```

## License

MIT
