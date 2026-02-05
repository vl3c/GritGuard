---
name: gritguard
description: Run commands in GritGuard sandbox for OS-level isolation. Use when executing untrusted code, AI agents, or any command that needs filesystem/network restrictions.
disable-model-invocation: true
argument-hint: [command] [args...]
---

# GritGuard

Lightweight OS-level sandboxing for AI agents and autonomous applications.

## Default Usage

```bash
./bin/gritguard $ARGUMENTS
```

## Quick Start

**Run any command in sandbox:**
```bash
gritguard your-command [args...]
```

**Run SelfAssembler on a project:**
```bash
gritguard selfassembler "Add feature" --repo /path/to/project
```

**Enable debug output:**
```bash
GRITGUARD_DEBUG=1 gritguard your-command
```

## Sandbox Features

- **Filesystem isolation**: Blocks access to ~/.ssh, ~/.aws, ~/.gnupg, /root
- **Network allowlisting**: Only permits approved domains (api.anthropic.com, api.openai.com, github.com)
- **Write restrictions**: Limits writes to target project directory
- **Dynamic config**: Auto-configures based on --repo target

## Dynamic Write Paths

When using `--repo`, GritGuard automatically allows writes to:
- Target directory (the project)
- `<target>/.worktrees` and `<target>/../.worktrees`
- `<target>/logs`
- `<target>/plans`
- `/tmp`

## Docker Mode

For Docker-based isolation (alternative to bubblewrap):

```bash
# Build sandbox image first
docker build -t gritguard-sandbox:latest ./docker/

# Run in Docker sandbox
./bin/gritguard-docker your-command [args...]

# With target directory
./bin/gritguard-docker selfassembler "Add feature" --repo /path/to/project
```

## Docker Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GRITGUARD_DOCKER_IMAGE` | Docker image to use | `gritguard-sandbox:latest` |
| `GRITGUARD_DOCKER_NETWORK` | Network mode: `bridge`, `none`, `host` | `bridge` |
| `GRITGUARD_DOCKER_PROXY` | Enable squid proxy for domain filtering | `0` |
| `GRITGUARD_DEBUG` | Enable debug output | `0` |

## Network Modes (Docker)

| Mode | Description |
|------|-------------|
| `bridge` (default) | Normal network access |
| `none` | Complete network isolation |
| `proxy` (`GRITGUARD_DOCKER_PROXY=1`) | Domain allowlisting via squid |

## Static Mode

For fixed configurations:

```bash
# Uses .srt-settings.json in current directory
./bin/sandboxed your-command [args...]

# Or specify settings file
GRITGUARD_SETTINGS=/path/to/config.json ./bin/sandboxed your-command
```

## Configuration Template

Edit `./templates/base.json`:

```json
{
  "filesystem": {
    "denyRead": ["$HOME/.ssh", "$HOME/.aws", "$HOME/.gnupg", "/root"],
    "allowWrite": [],
    "denyWrite": []
  },
  "network": {
    "allowedDomains": ["api.anthropic.com", "api.openai.com", "github.com"],
    "deniedDomains": [],
    "allowLocalBinding": true
  }
}
```

## Use Cases

- **AI Coding Agents**: Prevent agents from accessing credentials
- **Autonomous Workflows**: Limit blast radius of automated processes
- **Development Sandboxes**: Isolate experimental code execution
- **CI/CD Pipelines**: Secure build/test environments

## Requirements

- **Linux**: `bubblewrap` (bwrap), `socat`
- **macOS**: Built-in `sandbox-exec`
- **Docker mode**: Docker 20.10+

## Testing

```bash
# Run all tests
./tests/test_all.sh

# Quick mode (skip network tests)
./tests/test_all.sh --quick

# Only Docker tests
./tests/test_all.sh --docker
```
