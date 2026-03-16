# Claude Sandbox

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a lightweight Docker container using your host's native binary — no npm install, no image builds, instant startup.

## Why?

- **Sandboxed execution** — Claude Code runs in an isolated container, not directly on your host
- **Zero build time** — mounts the host's Claude binary directly, no Docker image to build or maintain
- **Always up to date** — uses whatever version is installed on your host
- **Full tooling** — all host binaries in `/usr/bin` are available via `/host/bin`
- **Seamless auth** — shares your existing OAuth session, SSH keys, git config, and AWS credentials

## Requirements

- Linux / WSL2
- Docker
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed on the host (`~/.local/bin/claude`)

## Quick Start

### 1. Install

```bash
git clone git@github.com:aeanez/claude-sandbox.git
cd claude-sandbox
bash install.sh
source ~/.bashrc
```

Or manually — copy the function and aliases from [`claude-sandbox.sh`](claude-sandbox.sh) into your `~/.bashrc`:

```bash
cat claude-sandbox.sh >> ~/.bashrc
source ~/.bashrc
```

### 2. Use

```bash
# Run Claude Code inside the sandbox
sandbox

# Run Claude Code with --dangerously-skip-permissions inside the sandbox
yolo
```

## Commands

| Command | Description |
|---------|-------------|
| `sandbox` | Runs `claude -c` inside the container at your current directory |
| `yolo` | Runs `claude -c --dangerously-skip-permissions` inside the container (hostname: `yolo`) |

Inside the sandbox you have full access to `claude`, `git`, `docker`, `ssh`, `jq`, `make`, and all other host binaries via `/host/bin`.

## How is this different from Claude Code's `/sandbox`?

Claude Code has a built-in `/sandbox` command that uses OS-level isolation (bubblewrap on Linux, Seatbelt on macOS) to restrict what individual tool calls can access. It's a security feature that limits filesystem writes and filters network requests.

This repo is different — it wraps the **entire Claude process** inside a Docker container:

| | Claude Code `/sandbox` | claude-sandbox (this repo) |
|---|---|---|
| **Scope** | Restricts individual Bash commands | Isolates the entire Claude session |
| **Technology** | OS-level (bubblewrap / Seatbelt) | Docker container |
| **Filesystem** | Write-restricted to CWD + allowlist | Container boundary — only sees mounted paths |
| **Network** | Proxy-based domain allowlist | Host network (no filtering) |
| **Tools** | Some break (docker, watchman) | All host binaries available via `/host/bin` |
| **Use case** | Hardened security for autonomous agents | Dev workflow with full autonomy (`yolo`) |

The main value here is the `yolo` workflow: run `--dangerously-skip-permissions` inside a disposable container where the blast radius is limited by Docker. You can also enable `/sandbox` *inside* the container for defense-in-depth.

## How It Works

```
Host (WSL2 / Linux)
 |
 ├── $HOME                 ──► mounted (full home directory)
 ├── /usr/bin              ──► mounted read-only to /host/bin
 ├── /usr/lib/git-core     ──► mounted read-only to /host/lib/git-core
 ├── /lib/x86_64-linux-gnu ──► mounted read-only (shared libraries)
 ├── /usr/bin/docker       ──► mounted read-only (resolved via readlink)
 ├── /var/run/docker.sock  ──► mounted (Docker-in-Docker access)
 └── /etc/passwd, /etc/group ► mounted read-only (uid resolution)
         │
         ▼
   ┌─────────────────────────────┐
   │  ubuntu:22.04 container     │
   │  (~70MB base image)         │
   │                             │
   │  - Host binaries in PATH    │
   │  - Same uid/gid as host     │
   │  - Host network mode        │
   │  - Working dir = host $PWD  │
   │  - Hostname: sandbox / yolo │
   └─────────────────────────────┘
```

The container runs as your host user (same uid/gid), uses host networking, and mounts your entire home directory. The working directory matches wherever you launched the command from.

## Configuration

### Base image

The default is `ubuntu:22.04` to match a typical WSL2 host. Change it in `claude-sandbox.sh` if your host runs a different distro.

### Hostname

The hostname defaults to `sandbox` and can be overridden via the `SANDBOX_HOSTNAME` environment variable. The `yolo` alias sets it to `yolo` automatically. Your PS1 should use `\h` to display it:

```bash
PS1="\h:\w\$ "
```

## Troubleshooting

### "No user exists for uid 1000"
SSH needs to resolve your user. The setup mounts `/etc/passwd` and `/etc/group` read-only to fix this.

### Claude asks for first-time setup
The installer handles this automatically. If it still happens, add `hasCompletedOnboarding: true` and `theme: "dark"` to `~/.claude/.claude.json`.

### Docker permission denied
The setup adds your user to the Docker socket's group via `--group-add`. If it still fails, check the socket permissions: `stat -c '%g' /var/run/docker.sock`.

### Tool not found
All host binaries from `/usr/bin` are mounted at `/host/bin` and added to `PATH`. If a binary lives elsewhere, add a `-v` mount for it in `claude-sandbox.sh`. Dynamically linked binaries work because `/lib/x86_64-linux-gnu` is mounted.

## License

MIT
