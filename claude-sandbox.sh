#!/usr/bin/env bash
# Claude Sandbox — Run Claude Code in a lightweight Docker container
# Source this file in your .bashrc or copy the contents directly

# Prune exited/dead sandbox containers
_sandbox_prune() {
  docker container prune --filter "label=claude-sandbox" -f >/dev/null 2>&1
}

# Core: launch a new sandbox container
_claude_docker() {
  local mode="${SANDBOX_HOSTNAME:-sandbox}"
  local dir_hash
  dir_hash=$(printf '%s' "$PWD" | md5sum | cut -c1-8)
  local name="claude-${mode}-${dir_hash}"

  # Prune dead sandbox containers on every launch
  _sandbox_prune

  # Stop existing container for this directory (if any)
  if docker ps -q --filter "name=^${name}$" | grep -q .; then
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

  # Load project-specific env vars from .sandbox.env
  local env_args=()
  if [[ -f "$PWD/.sandbox.env" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
      [[ -z "$line" || "$line" == \#* ]] && continue
      env_args+=(-e "$line")
    done < "$PWD/.sandbox.env"
  fi

  # Build PATH: include host PATH plus any extra tool directories
  local sandbox_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
  # Add AWS CLI dist directory if present
  [[ -x "$HOME/aws/dist/aws" ]] && sandbox_path="$HOME/aws/dist:$sandbox_path"

  local image="${SANDBOX_IMAGE:-ubuntu:22.04}"

  docker run -it --rm \
    --init \
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
    -v "$(readlink -f "$(which docker)"):/usr/local/bin/docker:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /etc:/etc:ro \
    "${extra_mounts[@]}" \
    "${env_args[@]}" \
    -w "$PWD" \
    "$image" \
    "$@"
}

# sandbox — subcommand interface
sandbox() {
  case "${1:-shell}" in
    shell)
      _claude_docker bash
      ;;
    ls|list)
      docker ps --filter "label=claude-sandbox" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Label \"claude-sandbox.dir\"}}"
      ;;
    stop)
      local containers
      containers=$(docker ps -q --filter "label=claude-sandbox")
      if [[ -n "$containers" ]]; then
        echo "$containers" | xargs docker stop >/dev/null
        _sandbox_prune
        echo "Stopped all sandbox containers."
      else
        echo "No running sandbox containers."
      fi
      ;;
    exec)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Usage: sandbox exec <command> [args...]"
        return 1
      fi
      _claude_docker "$@"
      ;;
    attach)
      local mode="${SANDBOX_HOSTNAME:-sandbox}"
      local dir_hash
      dir_hash=$(printf '%s' "$PWD" | md5sum | cut -c1-8)
      local name="claude-${mode}-${dir_hash}"
      if docker ps -q --filter "name=^${name}$" | grep -q .; then
        docker exec -it --user "$(id -u):$(id -g)" "$name" bash
      else
        echo "No running sandbox for this directory. Use 'sandbox' to start one."
      fi
      ;;
    help|-h|--help)
      cat <<'HELP'
sandbox — Docker sandbox for development

Commands:
  sandbox              Open an interactive shell (default)
  sandbox ls           List running sandbox containers
  sandbox stop         Stop all sandbox containers
  sandbox exec <cmd>   Run a one-off command in a new container
  sandbox attach       Attach to a running container for this directory

  yolo                 Run Claude Code with --dangerously-skip-permissions

Environment:
  SANDBOX_IMAGE        Override base image (default: ubuntu:22.04)
  SANDBOX_HOSTNAME     Override container hostname (default: sandbox)
  SANDBOX_MOUNTS       Extra bind mounts (newline-separated, -v syntax)

Per-project:
  .sandbox.env         Auto-loaded env vars (KEY=VALUE, one per line)
HELP
      ;;
    *)
      echo "Unknown command: $1 (try 'sandbox help')"
      return 1
      ;;
  esac
}

# Run Claude Code with --dangerously-skip-permissions inside the sandbox
alias yolo='SANDBOX_HOSTNAME=yolo _claude_docker bash -c "claude -c --dangerously-skip-permissions 2>/dev/null || claude --dangerously-skip-permissions"'
