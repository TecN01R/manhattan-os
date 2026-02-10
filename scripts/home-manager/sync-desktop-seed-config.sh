#!/usr/bin/env bash
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: sync-desktop-seed-config <home_dir> <seed_home> <username>" >&2
  exit 2
fi

home_dir="$1"
seed_home="$2"
username="$3"

sync_path() {
  src="$1"
  dst="$2"

  if [ -L "$dst" ] || [ -e "$dst" ]; then
    rm -rf "$dst"
  fi

  if [ ! -L "$src" ] && [ ! -e "$src" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"

  # Keep seed paths user-editable in the repo checkout.
  chmod -R u+rwX "$dst" 2>/dev/null || true
  chown -R "$username" "$dst" 2>/dev/null || true
}

sync_path "$home_dir/.config/niri" "$seed_home/.config/niri"
sync_path "$home_dir/.config/DankMaterialShell" "$seed_home/.config/DankMaterialShell"
# Do not persist DMS transient markers in seed.
rm -f \
  "$seed_home/.config/DankMaterialShell/.changelog-"* \
  "$seed_home/.config/DankMaterialShell/.firstlaunch"
sync_path "$home_dir/.local/state/DankMaterialShell/session.json" "$seed_home/.local/state/DankMaterialShell/session.json"
sync_path "$home_dir/Pictures/Wallpapers/gruvbox_astro.jpg" "$seed_home/Pictures/Wallpapers/gruvbox_astro.jpg"
