#!/usr/bin/env bash
# Claude Sandbox — macOS (Darwin) platform implementation

_sandbox_hash() {
  printf '%s' "$1" | md5 | cut -c1-8
}

# Auto-build macOS image if missing
_sandbox_ensure_image() {
  local image="${SANDBOX_IMAGE:-claude-sandbox:latest}"
  if ! docker image inspect "$image" &>/dev/null; then
    if [[ -z "${_SANDBOX_SCRIPT_DIR:-}" || ! -f "$_SANDBOX_SCRIPT_DIR/Dockerfile.macos" ]]; then
      echo "Error: Cannot find Dockerfile.macos. Re-run install.sh or set _SANDBOX_SCRIPT_DIR."
      return 1
    fi
    echo "The sandbox image '$image' is not built yet."
    read -rp "Build it now? This may take a few minutes. [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      docker build -t "$image" -f "$_SANDBOX_SCRIPT_DIR/Dockerfile.macos" "$_SANDBOX_SCRIPT_DIR"
    else
      echo "Aborted. Run 'make build' when ready."
      return 1
    fi
  fi
}

# Called by _claude_docker — assigns caller's local vars: image, sandbox_path, platform_args
_sandbox_platform_setup() {
  image="${SANDBOX_IMAGE:-claude-sandbox:latest}"
  sandbox_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  platform_args+=(
    -v /var/run/docker.sock:/var/run/docker.sock
  )
}
