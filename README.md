# GritGuard

Lightweight OS-level sandboxing for AI agents and autonomous applications.

## Features

- **Filesystem isolation**: Block access to sensitive directories (SSH keys, cloud credentials)
- **Network allowlisting**: Only permit connections to approved domains
- **Write restrictions**: Limit file modifications to specific directories
- **Dynamic config**: Automatically configures write paths for target project
- **Cross-platform**: Uses `bubblewrap` on Linux, `sandbox-exec` on macOS
- **Docker mode**: Alternative isolation using Docker containers

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

- Python 3.6+ (for config generation)
- Node.js 18+
- `@anthropic-ai/sandbox-runtime` npm package
- Linux: `bubblewrap` (`bwrap`), `socat`
- macOS: Built-in `sandbox-exec`
- Docker mode: Docker 20.10+

## Docker Mode

GritGuard supports Docker-based isolation as an alternative to bubblewrap/sandbox-exec.

### Setup

```bash
# Build the sandbox Docker image
docker build -t gritguard-sandbox:latest docker/
```

### Usage

```bash
# Run command in Docker sandbox
./bin/gritguard-docker your-command [args...]

# With explicit target directory
./bin/gritguard-docker selfassembler "Add feature" --repo /path/to/project

# Enable debug output
GRITGUARD_DEBUG=1 ./bin/gritguard-docker your-command
```

### Docker Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GRITGUARD_DOCKER_IMAGE` | Docker image to use | `gritguard-sandbox:latest` |
| `GRITGUARD_DOCKER_NETWORK` | Network mode: `bridge`, `none`, `host` | `bridge` |
| `GRITGUARD_DOCKER_PROXY` | Enable squid proxy for domain filtering | `0` |
| `GRITGUARD_DEBUG` | Enable debug output | `0` |

### Network Modes

- **bridge** (default): Normal network access, no domain filtering
- **none**: Complete network isolation (no outbound connections)
- **proxy** (`GRITGUARD_DOCKER_PROXY=1`): Domain allowlisting via squid proxy

### Docker vs Bubblewrap

| Feature | Docker | Bubblewrap |
|---------|--------|------------|
| Startup time | ~500ms-1s | ~50ms |
| Platform support | Any with Docker | Linux only |
| Sensitive path protection | Paths not mounted | Active blocking |
| Network domain filtering | Via squid proxy | Native support |

## Testing

```bash
# Full test suite (includes network tests)
./tests/test_sandbox.sh

# Quick tests (no network)
./tests/test_sandbox_quick.sh

# Docker sandbox tests
./tests/test_docker.sh
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
