#!/usr/bin/env bash
# Claude Sandbox installer
# Usage: git clone git@github.com:aeanez/claude-sandbox.git
#        cd claude-sandbox && bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/claude-sandbox.sh"
MARKER="# >>> claude-sandbox >>>"
MARKER_END="# <<< claude-sandbox <<<"

# Detect shell config file
case "$(basename "$SHELL")" in
  zsh)  RCFILE="$HOME/.zshrc" ;;
  *)    RCFILE="$HOME/.bashrc" ;;
esac

# Portable sed -i
_sed_inplace() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Check prerequisites
check_prereqs() {
  local missing=()
  command -v docker &>/dev/null || missing+=("docker")
  # On macOS, claude lives inside the container — not required on host
  if [[ "$(uname -s)" != "Darwin" ]]; then
    command -v claude &>/dev/null || missing+=("claude (https://docs.anthropic.com/en/docs/claude-code)")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing prerequisites:"
    for m in "${missing[@]}"; do
      echo "  - $m"
    done
    exit 1
  fi
}

# Ensure onboarding flags are set
setup_onboarding() {
  local claude_json="$HOME/.claude/.claude.json"
  if [[ -f "$claude_json" ]]; then
    if ! python3 - "$claude_json" <<'PYEOF' 2>/dev/null
import json, sys
claude_json = sys.argv[1]
with open(claude_json) as f:
    d = json.load(f)
if d.get('hasCompletedOnboarding') and d.get('theme'):
    sys.exit(0)
d['hasCompletedOnboarding'] = True
d.setdefault('theme', 'dark')
with open(claude_json, 'w') as f:
    json.dump(d, f, indent=2)
print(f'Set onboarding flags in {claude_json}')
PYEOF
    then
      echo "Warning: Could not update $claude_json — you may see the onboarding wizard in the container"
    fi
  fi
}

# Check if PS1 uses \h so the container hostname ("sandbox") is visible
update_ps1() {
  if grep -q 'PS1=' "$RCFILE" 2>/dev/null && ! grep -q '\\\\h' "$RCFILE" 2>/dev/null; then
    echo "Tip: Use \\h in your PS1 so the prompt shows 'sandbox' inside the container."
    echo "  Example: PS1='\\h:\\w\\\$ '"
  fi
}

# Install the sandbox function and aliases into shell rc file
install() {
  # Remove previous installation
  if grep -q "$MARKER" "$RCFILE" 2>/dev/null; then
    _sed_inplace "\|$MARKER|,\|$MARKER_END|d" "$RCFILE"
    echo "Removed previous claude-sandbox from $RCFILE"
  fi

  # Append new installation (sources from repo — changes take effect without reinstall)
  {
    echo ""
    echo "$MARKER"
    echo "_SANDBOX_SCRIPT_DIR=\"$SCRIPT_DIR\""
    echo "source \"\$_SANDBOX_SCRIPT_DIR/claude-sandbox.sh\""
    echo "$MARKER_END"
  } >> "$RCFILE"

  echo "Installed claude-sandbox into $RCFILE"
}

# Pull/build the base image (non-fatal)
setup_image() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "Building claude-sandbox image (this may take a few minutes)..."
    docker build -t claude-sandbox:latest -f "$SCRIPT_DIR/Dockerfile.macos" "$SCRIPT_DIR" \
      || echo "Warning: could not build image — it will be built on first run"
  else
    local image="${SANDBOX_IMAGE:-ubuntu:22.04}"
    echo "Pulling $image..."
    docker pull "$image" 2>/dev/null || echo "Warning: could not pull $image — continuing with cached image"
  fi
}

uninstall() {
  if grep -q "$MARKER" "$RCFILE" 2>/dev/null; then
    _sed_inplace "\|$MARKER|,\|$MARKER_END|d" "$RCFILE"
    echo "Removed claude-sandbox from $RCFILE"
    echo "Run 'source $RCFILE' to apply."
  else
    echo "claude-sandbox is not installed in $RCFILE"
  fi
}

main() {
  if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
    return
  fi
  echo "=== Claude Sandbox Installer ==="
  echo ""
  check_prereqs
  setup_onboarding
  update_ps1
  install
  setup_image
  echo ""
  echo "Done! Run 'source $RCFILE' then:"
  echo "  sandbox  — interactive shell in container"
  echo "  yolo     — claude with skip-permissions in container"
}

main "$@"
