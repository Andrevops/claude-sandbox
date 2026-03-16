# Claude Sandbox

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a lightweight Docker container using your host's native binary — no npm install, no image builds, instant startup.

## Why?

- **Sandboxed execution** — Claude Code runs in an isolated container, not directly on your host
- **Zero build time** — mounts the host's Claude binary directly, no Docker image to build or maintain
- **Always up to date** — uses whatever version is installed on your host
- **Full tooling** — git, docker, ssh, jq, make, and your custom tools are all available
- **Seamless auth** — shares your existing OAuth session, SSH keys, git config, and AWS credentials

## Requirements

- Linux / WSL2
- Docker
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed on the host (`~/.local/bin/claude`)

## Quick Start

### 1. Install

```bash
source <(curl -s https://raw.githubusercontent.com/YOUR_ORG/claude-sandbox/main/install.sh)
```

Or manually — copy the function and aliases from [`claude-sandbox.sh`](claude-sandbox.sh) into your `~/.bashrc`:

```bash
cat claude-sandbox.sh >> ~/.bashrc
source ~/.bashrc
```

### 2. First-time setup

Claude Code stores onboarding state in `~/.claude/.claude.json`. If the container prompts you for first-time setup, ensure these fields exist:

```bash
python3 -c "
import json
with open('$HOME/.claude/.claude.json', 'r') as f:
    data = json.load(f)
data['hasCompletedOnboarding'] = True
data['theme'] = 'dark'  # or 'light'
with open('$HOME/.claude/.claude.json', 'w') as f:
    json.dump(data, f, indent=2)
"
```

### 3. Use

```bash
# Drop into a bash shell inside the sandbox
sandbox

# Run Claude Code with --dangerously-skip-permissions (works inside or outside container)
yolo
```

## Commands

| Command | Description |
|---------|-------------|
| `sandbox` | Opens an interactive bash shell in the container at `$HOME` |
| `yolo` | Runs `claude -c --dangerously-skip-permissions` (works anywhere) |

Inside the sandbox you have full access to `claude`, `git`, `docker`, `ssh`, `jq`, `make`, and anything in `~/.local/bin`.

## How It Works

```
Host (WSL2 / Linux)
 |
 ├── ~/.local/bin/claude  ──► mounted read-only into container
 ├── ~/.claude/            ──► mounted (config, auth, sessions)
 ├── ~/.claude.json        ──► mounted (onboarding state)
 ├── $HOME                 ──► mounted (full home directory)
 ├── /lib/x86_64-linux-gnu ──► mounted read-only (shared libraries)
 ├── /var/run/docker.sock  ──► mounted (Docker-in-Docker access)
 └── /etc/passwd, /etc/group ► mounted read-only (uid resolution)
         │
         ▼
   ┌─────────────────────────┐
   │  ubuntu:22.04 container │
   │  (~70MB base image)     │
   │                         │
   │  - Host binary, no npm  │
   │  - Same uid/gid as host │
   │  - Host network mode    │
   │  - Hostname: "sandbox"  │
   └─────────────────────────┘
```

The container runs as your host user (same uid/gid), uses host networking, and mounts your entire home directory. The PS1 prompt shows `sandbox:` so you always know when you're inside the container.

## Configuration

### Base image

The default is `ubuntu:22.04` to match a typical WSL2 host. Change it in `claude-sandbox.sh` if your host runs a different distro.

### Host tools

Tools are mounted from the host via bind mounts. To add more:

```bash
-v /usr/bin/mytool:/usr/bin/mytool:ro \
```

If the tool is dynamically linked, the host's `/lib/x86_64-linux-gnu` is already mounted, so most Debian/Ubuntu binaries will work out of the box.

### Hostname

Change `--hostname sandbox` to whatever you prefer. Your PS1 should use `\h` to display it:

```bash
PS1="\h:\w\$ "
```

## Troubleshooting

### "No user exists for uid 1000"
SSH needs to resolve your user. The setup mounts `/etc/passwd` and `/etc/group` read-only to fix this.

### Claude asks for first-time setup
Add `hasCompletedOnboarding: true` and `theme: "dark"` to `~/.claude/.claude.json`. See [First-time setup](#2-first-time-setup).

### Docker permission denied
The setup adds your user to the Docker socket's group via `--group-add`. If it still fails, check the socket permissions: `stat -c '%g' /var/run/docker.sock`.

### Tool not found
If a host binary isn't available, add a `-v` mount for it. Statically linked binaries (Go, Rust) just work. Dynamically linked binaries work because `/lib/x86_64-linux-gnu` is mounted.

## License

MIT
