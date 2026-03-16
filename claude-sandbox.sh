#!/usr/bin/env bash
# Claude Sandbox — Run Claude Code in a lightweight Docker container
# Source this file in your .bashrc or copy the contents directly

_claude_docker() {
  docker run -it --rm \
    --user "$(id -u):$(id -g)" \
    --group-add "$(stat -c '%g' /var/run/docker.sock)" \
    --hostname sandbox \
    --network host \
    -e HOME="$HOME" \
    -e PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.local/bin" \
    -v "$HOME:$HOME" \
    -v /lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:ro \
    -v /usr/bin/git:/usr/bin/git:ro \
    -v /usr/lib/git-core:/usr/lib/git-core:ro \
    -v /usr/bin/jq:/usr/bin/jq:ro \
    -v /usr/bin/make:/usr/bin/make:ro \
    -v "$(readlink -f /usr/bin/docker):/usr/bin/docker:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -w "$PWD" \
    ubuntu:22.04 \
    "$@"
}

# Drop into an interactive bash shell inside the sandbox
alias sandbox='_claude_docker bash -l'

# Run Claude Code with --dangerously-skip-permissions (works inside or outside container)
alias yolo='claude -c --dangerously-skip-permissions'
