# Claude Sandbox

A lightweight Docker sandbox for development — drop into an isolated shell at your current directory with all your host tools available. Optionally run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with `--dangerously-skip-permissions` inside the container where the blast radius is limited by Docker.

## Why?

- **Sandboxed shell** — work inside a disposable container, not directly on your host
- **Zero build time** — mounts host binaries and libraries directly, no Docker image to build or maintain
- **Full tooling** — all host binaries in `/usr/bin` are available via `/host/bin`
- **Seamless auth** — shares your SSH keys, git config, and AWS credentials (read-only)

## Requirements

- Linux / WSL2
- Docker
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed on the host (`~/.local/bin/claude`) — only needed for the `yolo` command

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
# Open an interactive shell inside the sandbox
sandbox

# Run Claude Code with --dangerously-skip-permissions inside the sandbox
yolo
```

## Commands

| Command | Description |
|---------|-------------|
| `sandbox` | Opens an interactive bash shell inside the container at your current directory |
| `yolo` | Runs `claude --dangerously-skip-permissions` inside the container — resumes the last session if one exists, otherwise starts fresh (hostname: `yolo`) |

Inside the sandbox you have full access to `git`, `docker`, `ssh`, `jq`, `make`, and all other host binaries via `/host/bin`. You can also run `claude` manually from inside the shell.

## How is this different from Claude Code's `/sandbox`?

Claude Code has a built-in `/sandbox` command that uses OS-level isolation (bubblewrap on Linux, Seatbelt on macOS) to restrict what individual tool calls can access. It's a security feature that limits filesystem writes and filters network requests.

This repo is different — it wraps your **entire session** inside a Docker container:

| | Claude Code `/sandbox` | claude-sandbox (this repo) |
|---|---|---|
| **Scope** | Restricts individual Bash commands | Isolates the entire session |
| **Technology** | OS-level (bubblewrap / Seatbelt) | Docker container |
| **Filesystem** | Write-restricted to CWD + allowlist | Container boundary — only sees mounted paths |
| **Network** | Proxy-based domain allowlist | Host network (no filtering) |
| **Tools** | Some break (docker, watchman) | All host binaries available via `/host/bin` |
| **Use case** | Hardened security for autonomous agents | Dev workflow with full autonomy (`yolo`) |

The main value of `yolo` is running `--dangerously-skip-permissions` inside a disposable container where the blast radius is limited by Docker. You can also enable `/sandbox` *inside* the container for defense-in-depth.

## How It Works

```
Host (WSL2 / Linux)
 |
 ├── $HOME                 ──► mounted (full home directory)
 ├── /usr/bin              ──► mounted read-only to /host/bin
 ├── /usr/lib              ──► mounted read-only (shared libraries + git-core)
 ├── /lib/x86_64-linux-gnu ──► mounted read-only (shared libraries)
 ├── /usr/bin/docker       ──► mounted read-only (resolved via readlink)
 ├── /var/run/docker.sock  ──► mounted (Docker-in-Docker access)
 └── /etc/passwd, group,   ──► mounted read-only (uid resolution + manpath)
     manpath.config
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
   │  - PS1 shows hostname       │
   └─────────────────────────────┘
```

The container runs as your host user (same uid/gid), uses host networking, and mounts your entire home directory. The working directory matches wherever you launched the command from.

The container's prompt is overridden via `PROMPT_COMMAND` to show the container hostname (`sandbox` or `yolo`) regardless of your host's PS1 configuration.

## Configuration

### Base image

The default is `ubuntu:22.04` to match a typical WSL2 host. Change it in `claude-sandbox.sh` if your host runs a different distro.

### Hostname

The hostname defaults to `sandbox` and can be overridden via the `SANDBOX_HOSTNAME` environment variable. The `yolo` alias sets it to `yolo` automatically.

### Prompt

The container sets `PROMPT_COMMAND` to override PS1 with a colored prompt showing the hostname, working directory, and git branch. To customize it, edit the `PROMPT_COMMAND` env var in `claude-sandbox.sh`.

### Extra mounts

Set `SANDBOX_MOUNTS` in your `.bashrc` to bind additional paths into the container. Each line is a standard Docker `-v` mount spec:

```bash
export SANDBOX_MOUNTS="
  /mnt/c/Users/me/Documents/vault:/home/me/vault
  /opt/shared-tools:/opt/shared-tools:ro
"
```

This is useful for paths outside `$HOME` that the container needs access to, such as Windows filesystem paths on WSL2 or shared team directories. If unset, no extra mounts are added.

## How is this different from the official devcontainer?

Anthropic provides a [reference devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) for running Claude Code in a secure, reproducible environment. It's a different tool for a different job:

| | **claude-sandbox** (this repo) | **[Official devcontainer](https://code.claude.com/docs/en/devcontainer)** |
|---|---|---|
| **Approach** | Mount host binaries into a bare `ubuntu:22.04` | Build a full image from `node:20` with npm packages |
| **Build time** | Zero — just `docker pull ubuntu:22.04` | Full image build (npm install, zsh, git-delta, etc.) |
| **Claude install** | Uses host's binary via `$HOME/.local/bin` | `npm install -g @anthropic-ai/claude-code` baked in |
| **Updates** | Instant — always uses host's Claude version | Requires image rebuild |
| **Network security** | Host network, no filtering | Firewall with default-deny, whitelisted domains only |
| **Filesystem** | Mounts `$HOME` read-write, sensitive dirs read-only | Isolated `/workspace`, no host home mount |
| **Shell** | Bash (host's `.bashrc`) | Zsh + powerlevel10k + fzf |
| **Docker access** | Yes (socket mounted) | No |
| **IDE integration** | None (terminal-only) | VS Code Dev Containers extension |
| **Target use case** | Quick interactive shell / `yolo` mode | Team-wide standardized secure environment |

**When to use which:**
- **claude-sandbox** — personal dev workflow, quick experiments, need Docker/host tools inside the container
- **Official devcontainer** — team environments, CI/CD, autonomous agents where network isolation matters

## Security Considerations

This sandbox prioritizes **convenience over isolation**. It limits blast radius via Docker but is **not a security boundary** against a determined attacker. Understand what it does and doesn't protect before running untrusted code.

### What this sandbox provides

- **Process isolation** — the container is a separate PID/mount/UTS namespace, so a runaway process can't directly signal or inspect host processes
- **Disposable environment** — `--rm` ensures nothing persists in the container after exit; any damage is limited to mounted paths
- **Read-only sensitive dirs** — `.ssh`, `.aws`, `.gnupg` are overlaid as read-only, preventing accidental credential modification

### What it does NOT provide

- **Network isolation** — host network mode means the container has the same network access as your host. A malicious process can reach any endpoint you can, including internal services, cloud metadata APIs (`169.254.169.254`), and exfiltration targets. The [official devcontainer](https://code.claude.com/docs/en/devcontainer) solves this with a default-deny firewall that whitelists only npm, GitHub, and the Claude API.

- **Filesystem isolation** — `$HOME` is mounted read-write. The container can read/modify your git config, shell history, Claude credentials (`~/.claude`), and any file in your home directory. The official devcontainer isolates the workspace to `/workspace` with no host home mount.

- **Docker socket = root** — the mounted Docker socket gives the container full control over the Docker daemon, which is effectively root-equivalent on the host. It can spawn privileged containers, mount the host filesystem, or manipulate other running containers. Remove the `-v /var/run/docker.sock` line if you don't need Docker access.

- **No credential scoping** — Claude's API key and OAuth tokens in `~/.claude` are fully accessible. The official devcontainer warns that even with its firewall, `--dangerously-skip-permissions` doesn't prevent exfiltration of anything accessible in the container.

### Hardening options

To tighten security while keeping the convenience of this approach:

| Hardening | How |
|-----------|-----|
| Protect additional paths | Add read-only overlays: `-v "$HOME/.kube:$HOME/.kube:ro"` |
| Remove Docker access | Delete the `-v /var/run/docker.sock` and docker binary mount lines |
| Restrict network | Replace `--network host` with a custom Docker network + iptables rules |
| Defense-in-depth | Enable Claude Code's built-in `/sandbox` inside the container |
| Limit home exposure | Mount only the project directory instead of all of `$HOME` |

### Bottom line

Use this sandbox for **trusted development workflows** where you value speed and tool access over hard isolation. For running autonomous agents against untrusted repos, or in shared/production environments, use the [official devcontainer](https://code.claude.com/docs/en/devcontainer) with its network firewall and isolated workspace.

## Troubleshooting

### "No user exists for uid 1000"
SSH needs to resolve your user. The setup mounts `/etc/passwd` and `/etc/group` read-only to fix this.

### Claude asks for first-time setup
The installer handles this automatically. If it still happens, add `hasCompletedOnboarding: true` and `theme: "dark"` to `~/.claude/.claude.json`.

### Docker permission denied
The setup adds your user to the Docker socket's group via `--group-add`. If it still fails, check the socket permissions: `stat -c '%g' /var/run/docker.sock`.

### Tool not found
All host binaries from `/usr/bin` are mounted at `/host/bin` and added to `PATH`. If a binary lives elsewhere, add a `-v` mount for it in `claude-sandbox.sh`. Dynamically linked binaries work because `/lib/x86_64-linux-gnu` and `/usr/lib` are mounted.

## License

MIT
