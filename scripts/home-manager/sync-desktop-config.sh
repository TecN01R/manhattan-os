#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: sync-desktop-config <home_dir> <seed_home> <username>" >&2
  exit 2
fi

# Wallpaper sync is intentionally disabled for now.
#
# home_dir="$1"
# seed_home="$2"
# username="$3"
# wallpaper_rel="Pictures/Wallpapers/gruvbox_astro.jpg"
#
# sync_path() {
#   src="$1"
#   dst="$2"
#
#   if [ ! -e "$src" ] && [ ! -L "$src" ]; then
#     return 0
#   fi
#
#   if [ -L "$dst" ] || [ -e "$dst" ]; then
#     rm -rf "$dst"
#   fi
#
#   mkdir -p "$(dirname "$dst")"
#   cp -R "$src" "$dst"
#
#   chmod -R u+rwX "$dst" 2>/dev/null || true
#   chown -R "$username" "$dst" 2>/dev/null || true
# }
#
# sync_path "$home_dir/$wallpaper_rel" "$seed_home/$wallpaper_rel"
