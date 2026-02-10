#!/usr/bin/env bash
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: seed-desktop-config <seed_home> <home_dir> <username>" >&2
  exit 2
fi

seed_home="$1"
home_dir="$2"
username="$3" 

seed_path() {
  src="$1"
  dst="$2"

  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  fi

  # Seed sources are copied through the Nix store, so keep targets editable.
  chmod -R u+rwX "$dst" 2>/dev/null || true
  chown -R "$username" "$dst" 2>/dev/null || true
}

seed_path "$seed_home/.config/niri" "$home_dir/.config/niri"
seed_path "$seed_home/.config/DankMaterialShell" "$home_dir/.config/DankMaterialShell"
seed_path "$seed_home/.local/state/DankMaterialShell/session.json" "$home_dir/.local/state/DankMaterialShell/session.json"
seed_path "$seed_home/Pictures/Wallpapers/gruvbox_astro.jpg" "$home_dir/Pictures/Wallpapers/gruvbox_astro.jpg"
