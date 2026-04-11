#!/bin/bash
# Add current user to /etc/passwd and /etc/group if not present
# This runs as the non-root user (--user flag) but passwd/group are world-writable
if ! getent passwd "$(id -u)" &>/dev/null; then
  echo "${USER:-user}:x:$(id -u):$(id -g)::${HOME:-/home/user}:/bin/bash" >> /etc/passwd
fi
if ! getent group "$(id -g)" &>/dev/null; then
  echo "${USER:-user}:x:$(id -g):" >> /etc/group
fi
exec "$@"
