#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: seed-desktop-config [--force|-f] [<seed_home> <home_dir> <username>]" >&2
}

force=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force|-f)
      force=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  username="${USER:-$(id -un)}"
  home_dir="${HOME:-/home/$username}"
  seed_home="${SEED_HOME:-/etc/nixos/seed/home/$username}"
elif [ "$#" -eq 3 ]; then
  seed_home="$1"
  home_dir="$2"
  username="$3"
else
  usage
  exit 2
fi

default_icon_theme="MoreWaita"
ghostty_rel=".config/ghostty/config"

# Disabled wallpaper seeding (kept here for easy re-enable later).
# wallpaper_rel="Pictures/Wallpapers/gruvbox_astro.jpg"

set_gnome_icon_theme() {
  gsettings set org.gnome.desktop.interface icon-theme "$default_icon_theme" >/dev/null 2>&1 || true
}

# seed_path "$seed_home/$wallpaper_rel" "$home_dir/$wallpaper_rel"
ghostty_src="$seed_home/$ghostty_rel"
ghostty_dst="$home_dir/$ghostty_rel"
if [ -e "$ghostty_src" ] || [ -L "$ghostty_src" ]; then
  if [ "$force" -eq 1 ]; then
    if [ -e "$ghostty_dst" ] || [ -L "$ghostty_dst" ]; then
      rm -rf "$ghostty_dst"
    fi
  elif [ -L "$ghostty_dst" ]; then
    rm -f "$ghostty_dst"
  fi

  if [ "$force" -eq 1 ] || [ ! -e "$ghostty_dst" ]; then
    mkdir -p "$(dirname "$ghostty_dst")"
    cp -R "$ghostty_src" "$ghostty_dst"
    chmod -R u+rwX "$ghostty_dst" 2>/dev/null || true
    chown -R "$username" "$ghostty_dst" 2>/dev/null || true
  fi
fi
set_gnome_icon_theme
