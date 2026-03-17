#!/usr/bin/env bash
# Claude Sandbox installer
# Usage: git clone git@github.com:aeanez/claude-sandbox.git
#        cd claude-sandbox && bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/claude-sandbox.sh"
BASHRC="$HOME/.bashrc"
MARKER="# >>> claude-sandbox >>>"
MARKER_END="# <<< claude-sandbox <<<"

# Check prerequisites
check_prereqs() {
  local missing=()
  command -v docker &>/dev/null || missing+=("docker")
  command -v claude &>/dev/null || missing+=("claude (https://docs.anthropic.com/en/docs/claude-code)")

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
  if grep -qP 'PS1=.*(?!\\\\h)' "$BASHRC" 2>/dev/null && ! grep -q '\\\\h' "$BASHRC" 2>/dev/null; then
    echo "Tip: Use \\h in your PS1 so the prompt shows 'sandbox' inside the container."
    echo "  Example: PS1='\\h:\\w\\\$ '"
  fi
}

# Install the sandbox function and aliases into .bashrc
install() {
  # Remove previous installation
  if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    sed -i "\|$MARKER|,\|$MARKER_END|d" "$BASHRC"
    echo "Removed previous claude-sandbox from .bashrc"
  fi

  # Append new installation
  {
    echo ""
    echo "$MARKER"
    cat "$SOURCE_FILE"
    echo "$MARKER_END"
  } >> "$BASHRC"

  echo "Installed claude-sandbox into $BASHRC"
}

# Pull the base image
pull_image() {
  echo "Pulling ubuntu:22.04..."
  docker pull ubuntu:22.04
}

main() {
  echo "=== Claude Sandbox Installer ==="
  echo ""
  check_prereqs
  setup_onboarding
  update_ps1
  install
  pull_image
  echo ""
  echo "Done! Run 'source ~/.bashrc' then:"
  echo "  sandbox  — interactive shell in container"
  echo "  yolo     — claude with skip-permissions in container"
}

main
