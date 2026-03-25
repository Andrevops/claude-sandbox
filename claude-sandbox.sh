#!/usr/bin/env bash
# Claude Sandbox — Run Claude Code in a lightweight Docker container
# Source this file in your .bashrc or copy the contents directly

_claude_docker() {
  local mode="${SANDBOX_HOSTNAME:-sandbox}"
  local dir_hash
  dir_hash=$(printf '%s' "$PWD" | md5sum | cut -c1-8)
  local name="claude-${mode}-${dir_hash}"
  # Stop orphaned container for this directory (if any)
  if docker ps -a -q --filter "name=^${name}$" | grep -q .; then
    docker rm -f "$name" >/dev/null 2>&1
  fi
  # SANDBOX_MOUNTS: newline-separated list of Docker bind mounts to add
  # Each line uses standard -v syntax (src:dest or src:dest:ro)
  # Example:
  #   export SANDBOX_MOUNTS="
  #     /mnt/c/Users/me/Documents/vault:/data/vault
  #     /opt/tools:/opt/tools:ro
  #   "
  local extra_mounts=()
  while IFS= read -r m; do
    m="${m#"${m%%[![:space:]]*}"}"  # trim leading whitespace
    [[ -n "$m" ]] && extra_mounts+=(-v "$m")
  done <<< "${SANDBOX_MOUNTS:-}"
  # Build PATH: include host PATH plus any extra tool directories
  local sandbox_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
  # Add AWS CLI dist directory if present
  [[ -x "$HOME/aws/dist/aws" ]] && sandbox_path="$HOME/aws/dist:$sandbox_path"
  docker run -it --rm \
    --name "$name" \
    --label "claude-sandbox" \
    --label "claude-sandbox.dir=$PWD" \
    --user "$(id -u):$(id -g)" \
    --group-add "$(stat -c '%g' /var/run/docker.sock)" \
    --hostname "${SANDBOX_HOSTNAME:-sandbox}" \
    --network host \
    -e HOME="$HOME" \
    -e PATH="$sandbox_path" \
    -e PROMPT_COMMAND='PS1="\[\033[1;36m\]\h\[\033[0m\]:\[\033[1;33m\]\w\[\033[0m\]\[\033[1;32m\]$(parse_git_branch 2>/dev/null)\[\033[0m\]\[\033[1;37m\]\$ \[\033[0m\]"' \
    -v "$HOME:$HOME" \
    -v "$HOME/.ssh:$HOME/.ssh:ro" \
    -v "$HOME/.aws:$HOME/.aws" \
    -v "$HOME/.gnupg:$HOME/.gnupg:ro" \
    -v /lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:ro \
    -v /usr/lib:/usr/lib:ro \
    -v /usr/share:/usr/share:ro \
    -v /usr/bin:/usr/bin:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /etc:/etc:ro \
    "${extra_mounts[@]}" \
    -w "$PWD" \
    ubuntu:22.04 \
    "$@"
}

# Open an interactive shell inside the sandbox
alias sandbox='_claude_docker bash'

# Run Claude Code with --dangerously-skip-permissions inside the sandbox
alias yolo='SANDBOX_HOSTNAME=yolo _claude_docker bash -c "claude -c --dangerously-skip-permissions 2>/dev/null || claude --dangerously-skip-permissions"'
