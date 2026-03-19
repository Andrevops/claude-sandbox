#!/usr/bin/env bash
# Claude Sandbox — Run Claude Code in a lightweight Docker container
# Source this file in your .bashrc or copy the contents directly

_claude_docker() {
  docker run -it --rm \
    --user "$(id -u):$(id -g)" \
    --group-add "$(stat -c '%g' /var/run/docker.sock)" \
    --hostname "${SANDBOX_HOSTNAME:-sandbox}" \
    --network host \
    -e HOME="$HOME" \
    -e PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/host/bin:$HOME/.local/bin" \
    -e PROMPT_COMMAND='PS1="\[\033[1;36m\]\h\[\033[0m\]:\[\033[1;33m\]\w\[\033[0m\]\[\033[1;32m\]$(parse_git_branch 2>/dev/null)\[\033[0m\]\[\033[1;37m\]\$ \[\033[0m\]"' \
    -v "$HOME:$HOME" \
    -v "$HOME/.ssh:$HOME/.ssh:ro" \
    -v "$HOME/.aws:$HOME/.aws:ro" \
    -v "$HOME/.gnupg:$HOME/.gnupg:ro" \
    -v /lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:ro \
    -v /usr/lib:/usr/lib:ro \
    -v /usr/bin:/host/bin:ro \
    -v "$(readlink -f /usr/bin/docker):/usr/bin/docker:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /etc/manpath.config:/etc/manpath.config:ro \
    -w "$PWD" \
    ubuntu:22.04 \
    "$@"
}

# Open an interactive shell inside the sandbox
alias sandbox='_claude_docker bash'

# Run Claude Code with --dangerously-skip-permissions inside the sandbox
alias yolo='SANDBOX_HOSTNAME=yolo _claude_docker bash -c "claude -c --dangerously-skip-permissions 2>/dev/null || claude --dangerously-skip-permissions"'
