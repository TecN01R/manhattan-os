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

# Wire DMS Zen theme output into any existing Zen profiles.
if [ -d "$home_dir/.zen" ]; then
  dms_zen_css="file://$home_dir/.config/DankMaterialShell/zen.css"
  while IFS= read -r -d '' profile_dir; do
    chrome_dir="$profile_dir/chrome"
    user_chrome="$chrome_dir/userChrome.css"
    user_js="$profile_dir/user.js"

    if [ ! -e "$user_chrome" ] && [ ! -L "$user_chrome" ]; then
      mkdir -p "$chrome_dir"
      printf '%s\n' "@import url(\"$dms_zen_css\");" > "$user_chrome"
    fi

    if [ ! -e "$user_js" ] && [ ! -L "$user_js" ]; then
      printf '%s\n' "user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);" > "$user_js"
    fi
  done < <(find "$home_dir/.zen" -mindepth 1 -maxdepth 1 -type d -print0)
fi
