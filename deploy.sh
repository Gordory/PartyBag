#!/usr/bin/env bash
# Copies the addon into the game's AddOns folder.
# Usage: ./deploy.sh [flavor]        flavor defaults to _forever_
#        DRY_RUN=1 ./deploy.sh       show what would change
#        WOW_DIR=/path ./deploy.sh   different install location
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WOW_DIR="${WOW_DIR:-/Volumes/Data/Games/World of Warcraft}"
FLAVOR="${1:-_forever_}"
ADDON="PartyBag"

SRC="$SCRIPT_DIR/"
ADDONS_DIR="$WOW_DIR/$FLAVOR/Interface/AddOns"
DEST="$ADDONS_DIR/$ADDON/"

# Refuse to create the AddOns tree ourselves: a missing folder means a wrong path, not a fresh install.
if [[ ! -d "$ADDONS_DIR" ]]; then
    echo "AddOns folder not found: $ADDONS_DIR" >&2
    exit 1
fi

# Mirrors .pkgmeta so the local copy matches what CurseForge users get; '.*' also covers .git, .worktrees and macOS ._ files.
RSYNC_ARGS=(-a --delete --itemize-changes --exclude '.*' --exclude 'deploy.sh' --exclude 'README.md' --exclude 'art' --exclude 'curseforge')
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    RSYNC_ARGS+=(--dry-run)
else
    mkdir -p "$DEST"
fi

# --delete is scoped to the addon's own folder so files removed from the repo don't linger in-game.
rsync "${RSYNC_ARGS[@]}" "$SRC" "$DEST"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "Dry run, nothing copied -> $DEST"
    exit 0
fi
echo "Deployed $ADDON -> $DEST"
echo "In game: /reload (new .lua/.toc files need a full client restart)"
