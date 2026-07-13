#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/lad"
TARGET_DIR="${LAD_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="$TARGET_DIR/lad"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

[[ -x "$SOURCE" ]] || { echo "lad source is missing or not executable: $SOURCE" >&2; exit 1; }
mkdir -p "$TARGET_DIR"

if [[ -L "$TARGET" ]]; then
  current="$(readlink "$TARGET")"
  if [[ "$current" == "$SOURCE" ]]; then
    echo "lad is already linked: $TARGET -> $SOURCE"
    exit 0
  fi
  mv "$TARGET" "$TARGET.backup-$STAMP"
elif [[ -e "$TARGET" ]]; then
  mv "$TARGET" "$TARGET.backup-$STAMP"
fi

ln -s "$SOURCE" "$TARGET"
echo "Installed lad: $TARGET -> $SOURCE"
echo "Ensure $TARGET_DIR is on PATH."
echo "When run from a git repository, lad targets that current working directory repo unless LAD_REPO_ROOT is set."
