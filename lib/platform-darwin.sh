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

# Ensure a named volume exists and is owned by the current user.
# Fresh volumes inherit root ownership from the image, which blocks --user writes.
_sandbox_ensure_volume() {
  # NOTE: avoid the local name `path` — in zsh it's tied to $PATH and would
  # clobber the caller's PATH (which broke docker/id lookup before this fix).
  local name="$1" mount="$2"
  local img="${SANDBOX_IMAGE:-claude-sandbox:latest}"
  if ! docker volume inspect "$name" &>/dev/null; then
    echo "Initializing sandbox volume '$name' at $mount..."
    docker volume create "$name" >/dev/null || return 1
    docker run --rm -u 0 -v "$name:$mount" --entrypoint chown "$img" \
      -R "$(id -u):$(id -g)" "$mount" >/dev/null || return 1
  fi
}

# Called by _claude_docker — assigns caller's local vars: image, sandbox_path, platform_args
_sandbox_platform_setup() {
  image="${SANDBOX_IMAGE:-claude-sandbox:latest}"
  sandbox_path="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

  # macOS uses named volumes for persistence — host binds aren't useful since
  # macOS binaries can't run inside the Linux container. The container is the
  # dev environment; volumes survive --rm and image rebuilds.
  _SANDBOX_HOST_HOME=0

  local prefix="${SANDBOX_VOLUME_PREFIX:-claude-sandbox}"
  _sandbox_ensure_volume "${prefix}-home" "$HOME" || return 1
  _sandbox_ensure_volume "${prefix}-tmp"  "/tmp"  || return 1
  _sandbox_ensure_volume "${prefix}-opt"  "/opt"  || return 1

  platform_args+=(
    -v /var/run/docker.sock:/var/run/docker.sock
    -v "${prefix}-home:$HOME"
    -v "${prefix}-tmp:/tmp"
    -v "${prefix}-opt:/opt"
  )
}
