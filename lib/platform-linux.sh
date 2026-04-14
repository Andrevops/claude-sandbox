#!/usr/bin/env bash
# Claude Sandbox — Linux / WSL2 platform implementation

_sandbox_hash() {
  printf '%s' "$1" | md5sum | cut -c1-8
}

_sandbox_ensure_image() {
  return 0
}

# Called by _claude_docker — assigns caller's local vars: image, sandbox_path, platform_args
_sandbox_platform_setup() {
  image="${SANDBOX_IMAGE:-ubuntu:22.04}"
  sandbox_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
  # Add AWS CLI dist directory if present
  [[ -x "$HOME/aws/dist/aws" ]] && sandbox_path="$HOME/aws/dist:$sandbox_path"
  platform_args+=(
    --group-add "$(stat -c '%g' /var/run/docker.sock)"
    -v /lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:ro
    -v /usr/lib:/usr/lib:ro
    -v /usr/share:/usr/share:ro
    -v /usr/bin:/usr/bin:ro
    -v "$(readlink -f "$(which docker)"):/usr/local/bin/docker:ro"
    -v /var/run/docker.sock:/var/run/docker.sock
    -v /etc:/etc:ro
    -v "$HOME/.local/bin:$HOME/.local/bin:ro"
    -v "$HOME/.local/share/claude:$HOME/.local/share/claude:ro"
  )
  # Mount shell init files so the container gets env vars, aliases, and tool init
  [[ -f "$HOME/.bashrc" ]]  && platform_args+=(-v "$HOME/.bashrc:$HOME/.bashrc:ro")
  [[ -f "$HOME/.profile" ]] && platform_args+=(-v "$HOME/.profile:$HOME/.profile:ro")
  # Mount nvm if present (node installed via nvm won't be in /usr/bin)
  [[ -d "$HOME/.nvm" ]]   && platform_args+=(-v "$HOME/.nvm:$HOME/.nvm:ro")
  # Mount cargo/rust if present (.bashrc and .profile source ~/.cargo/env)
  [[ -d "$HOME/.cargo" ]] && platform_args+=(-v "$HOME/.cargo:$HOME/.cargo:ro")
}
