#!/bin/sh
# uninstall.sh - remove this project's generated Little Coder/Rapid-MLX wiring
set -eu

MANIFEST_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
MANIFEST="$MANIFEST_DIR/install-manifest"
[ -f "$MANIFEST" ] || { printf '%s\n' "No install manifest at $MANIFEST." >&2; exit 1; }

get() { grep "^$1=" "$MANIFEST" 2>/dev/null | cut -d= -f2- || true; }
restore() {
  file="$1"; backup="$file.pre-local-agentic-dev"
  if [ -f "$backup" ]; then
    [ -f "$file" ] && mv "$file" "$file.removed-local-agentic-dev"
    mv "$backup" "$file"
    printf 'Restored %s\n' "$file"
  elif [ -f "$file" ]; then
    mv "$file" "$file.removed-local-agentic-dev"
    printf 'Removed generated %s\n' "$file"
  fi
}

agent="$(get rapid_mlx_launch_agent)"
label="$(get rapid_mlx_launch_label)"
if [ -n "$agent" ]; then
  launchctl bootout "gui/$(id -u)" "$agent" >/dev/null 2>&1 || true
  rm -f "$agent"
elif [ -n "$label" ]; then
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
fi

restore "$(get little_coder_models)"
pi_compat="$(get pi_compat)"
if [ -n "$pi_compat" ] && [ -f "$pi_compat" ] && grep -Fq 'Compatibility command for Little Coder' "$pi_compat"; then
  rm -f "$pi_compat"
  printf 'Removed generated %s\n' "$pi_compat"
fi
rm -f "$MANIFEST"
rmdir "$MANIFEST_DIR" 2>/dev/null || true
printf '%s\n' 'Removed generated Little Coder/Rapid-MLX wiring.'
printf '%s\n' 'Kept: Nail model cache, Rapid-MLX package, Little Coder package, and unrelated tools.'
