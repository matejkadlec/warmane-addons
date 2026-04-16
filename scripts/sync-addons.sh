#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env.sync-addons}"

if [[ -f "$ENV_FILE" ]]; then
  # Load local sync overrides without committing machine-specific paths.
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

SOURCE_DIR="${SYNC_ADDONS_SOURCE_DIR:-$REPO_ROOT/addons}"
DEST_DIR="${SYNC_ADDONS_DEST_DIR:-}"
AUTO_INSTALL_RSYNC="${SYNC_ADDONS_AUTO_INSTALL_RSYNC:-0}"
RSYNC_BIN="${SYNC_ADDONS_RSYNC_BIN:-}"

IsEnabled() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ResolveRsyncBin() {
  if [[ -n "$RSYNC_BIN" ]]; then
    return
  fi

  RSYNC_BIN="$(command -v rsync || true)"

  if [[ -n "$RSYNC_BIN" ]]; then
    return
  fi

  if ! IsEnabled "$AUTO_INSTALL_RSYNC"; then
    echo "rsync installation is disabled. To enable it for faster sync, set SYNC_ADDONS_AUTO_INSTALL_RSYNC to true in $ENV_FILE."
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "rsync not found, attempting to install it via apt-get"

    if [[ "$(id -u)" -eq 0 ]]; then
      if ! apt-get update || ! apt-get install -y rsync; then
        echo "Automatic rsync installation failed, using cp fallback instead." >&2
        return
      fi
    elif command -v sudo >/dev/null 2>&1; then
      if ! sudo apt-get update || ! sudo apt-get install -y rsync; then
        echo "Automatic rsync installation failed, using cp fallback instead." >&2
        return
      fi
    else
      echo "sudo is not available, cannot install rsync automatically." >&2
      return
    fi

    RSYNC_BIN="$(command -v rsync || true)"
  else
    echo "apt-get is not available, cannot install rsync automatically." >&2
  fi
}

ResolveRsyncBin

if [[ -z "$DEST_DIR" ]]; then
  echo "SYNC_ADDONS_DEST_DIR is not set. Configure it in $ENV_FILE." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Source addons directory not found: $SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -d "$DEST_DIR" ]]; then
  echo "Destination AddOns directory not found: $DEST_DIR" >&2
  exit 1
fi

mapfile -t addon_dirs < <(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#addon_dirs[@]} -eq 0 ]]; then
  echo "No addon directories found in: $SOURCE_DIR" >&2
  exit 1
fi

for addon_dir in "${addon_dirs[@]}"; do
  addon_name="$(basename "$addon_dir")"

  if ! find "$addon_dir" -mindepth 1 -maxdepth 1 -name "*.toc" | grep -q .; then
    echo "Skipping $addon_name (no .toc file found)"
    continue
  fi

  echo "Syncing $addon_name"

  if [[ -n "$RSYNC_BIN" ]]; then
    "$RSYNC_BIN" -a --delete "$addon_dir/" "$DEST_DIR/$addon_name/"
  else
    echo "rsync unavailable, using cp fallback for $addon_name"
    rm -rf "$DEST_DIR/$addon_name"
    mkdir -p "$DEST_DIR/$addon_name"
    cp -a "$addon_dir/." "$DEST_DIR/$addon_name/"
  fi
done

echo "Addon sync completed."
