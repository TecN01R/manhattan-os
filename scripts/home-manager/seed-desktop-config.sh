#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: seed-desktop-config [--force|-f] <seed_home> <home_dir> <username>" >&2
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

if [ "$#" -ne 3 ]; then
  usage
  exit 2
fi

seed_home="$1"
home_dir="$2"
username="$3"

default_icon_theme="Gruvbox-Plus-Dark"
default_cursor_theme="Capitaine Cursors (Gruvbox) - White"
default_cursor_size="24"

config_root="${XDG_CONFIG_HOME:-$home_dir/.config}"
cache_root="${XDG_CACHE_HOME:-$home_dir/.cache}"
state_root="${XDG_STATE_HOME:-$home_dir/.local/state}"

dms_config_dir="$config_root/DankMaterialShell"
settings_json="$dms_config_dir/settings.json"
session_json="$state_root/DankMaterialShell/session.json"
cache_dir="$cache_root/DankMaterialShell"
colors_json="$cache_dir/dms-colors.json"
gtk3_dir="$config_root/gtk-3.0"
gtk4_dir="$config_root/gtk-4.0"

icon_theme="$default_icon_theme"
cursor_theme="$default_cursor_theme"
cursor_size="$default_cursor_size"
matugen_type="scheme-tonal-spot"
mode="dark"
wallpaper_value="$home_dir/Pictures/Wallpapers/gruvbox_astro.jpg"

seed_path() {
  src="$1"
  dst="$2"

  if [ "$force" -eq 1 ]; then
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      rm -rf "$dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  else
    if [ -L "$dst" ]; then
      rm -f "$dst"
    fi

    if [ ! -e "$dst" ]; then
      mkdir -p "$(dirname "$dst")"
      cp -R "$src" "$dst"
    fi
  fi

  # Seed sources are copied through the Nix store, so keep targets editable.
  chmod -R u+rwX "$dst" 2>/dev/null || true
  chown -R "$username" "$dst" 2>/dev/null || true
}

ensure_gtk_setting() {
  settings_file="$1"
  key="$2"
  value="$3"

  if [ ! -e "$settings_file" ]; then
    printf '[Settings]\n%s=%s\n' "$key" "$value" >"$settings_file"
    return
  fi

  if ! grep -q '^\[Settings\]' "$settings_file"; then
    printf '\n[Settings]\n' >>"$settings_file"
  fi

  if ! grep -q "^$key=" "$settings_file"; then
    sed -i "/^\[Settings\]/a $key=$value" "$settings_file"
  fi
}

load_dms_settings() {
  if [ ! -f "$settings_json" ]; then
    return
  fi

  icon_theme="$(jq -r '.iconTheme // empty' "$settings_json" 2>/dev/null || true)"
  if [ -z "$icon_theme" ] || [ "$icon_theme" = "System Default" ] || [ "$icon_theme" = "null" ]; then
    icon_theme="$default_icon_theme"
  fi

  cursor_theme="$(jq -r '.cursorSettings.theme // empty' "$settings_json" 2>/dev/null || true)"
  if [ -z "$cursor_theme" ] || [ "$cursor_theme" = "System Default" ] || [ "$cursor_theme" = "null" ]; then
    cursor_theme="$default_cursor_theme"
  fi

  cursor_size="$(jq -r '.cursorSettings.size // empty' "$settings_json" 2>/dev/null || true)"
  if ! [[ "$cursor_size" =~ ^[0-9]+$ ]]; then
    cursor_size="$default_cursor_size"
  fi

  matugen_type="$(jq -r '.matugenScheme // empty' "$settings_json" 2>/dev/null || true)"
  if [ -z "$matugen_type" ] || [ "$matugen_type" = "null" ]; then
    matugen_type="scheme-tonal-spot"
  fi

  if [ -f "$session_json" ]; then
    is_light="$(jq -r '.isLightMode // false' "$session_json" 2>/dev/null || true)"
    if [ "$is_light" = "true" ]; then
      mode="light"
    fi

    session_wallpaper="$(jq -r '.wallpaperPath // empty' "$session_json" 2>/dev/null || true)"
    if [ -n "$session_wallpaper" ] && [ "$session_wallpaper" != "null" ]; then
      wallpaper_value="$session_wallpaper"
    fi
  fi
}

bootstrap_dms_theme_if_missing() {
  if [ ! -f "$settings_json" ]; then
    return
  fi

  mkdir -p "$cache_dir" "$gtk3_dir" "$gtk4_dir"

  dms_bin="$(command -v dms || true)"
  if [ -z "$dms_bin" ]; then
    return
  fi

  dms_store_dir="$(dirname "$(dirname "$(realpath "$dms_bin")")")"
  shell_dir="$dms_store_dir/share/quickshell/dms"
  if [ ! -d "$shell_dir" ]; then
    return
  fi

  needs_generation=0
  if [ ! -f "$colors_json" ] || [ ! -f "$gtk3_dir/dank-colors.css" ] || [ ! -f "$gtk4_dir/dank-colors.css" ]; then
    needs_generation=1
  fi

  if [ "$needs_generation" -eq 1 ]; then
    kind="image"
    value="$wallpaper_value"
    if [[ "$value" == \#* ]]; then
      kind="hex"
    elif [ ! -f "$value" ]; then
      kind="hex"
      value="#282828"
    fi

    backup_dir="$(mktemp -d)"
    had_colors_json=0
    had_gtk3_colors=0
    had_gtk4_colors=0

    if [ -f "$colors_json" ]; then
      had_colors_json=1
      cp -f "$colors_json" "$backup_dir/colors_json"
    fi
    if [ -f "$gtk3_dir/dank-colors.css" ]; then
      had_gtk3_colors=1
      cp -f "$gtk3_dir/dank-colors.css" "$backup_dir/gtk3_dank_colors.css"
    fi
    if [ -f "$gtk4_dir/dank-colors.css" ]; then
      had_gtk4_colors=1
      cp -f "$gtk4_dir/dank-colors.css" "$backup_dir/gtk4_dank_colors.css"
    fi

    dms matugen generate \
      --config-dir "$dms_config_dir" \
      --state-dir "$cache_dir" \
      --shell-dir "$shell_dir" \
      --kind "$kind" \
      --value "$value" \
      --mode "$mode" \
      --icon-theme "$icon_theme" \
      --matugen-type "$matugen_type" \
      --sync-mode-with-portal

    if [ "$had_colors_json" -eq 1 ]; then
      cp -f "$backup_dir/colors_json" "$colors_json"
    fi
    if [ "$had_gtk3_colors" -eq 1 ]; then
      cp -f "$backup_dir/gtk3_dank_colors.css" "$gtk3_dir/dank-colors.css"
    fi
    if [ "$had_gtk4_colors" -eq 1 ]; then
      cp -f "$backup_dir/gtk4_dank_colors.css" "$gtk4_dir/dank-colors.css"
    fi
    rm -rf "$backup_dir"
  fi

  needs_gtk_apply=0
  if [ ! -f "$gtk3_dir/gtk.css" ] || [ ! -f "$gtk4_dir/gtk.css" ]; then
    needs_gtk_apply=1
  fi

  if [ -x "$shell_dir/scripts/gtk.sh" ] && [ -f "$gtk3_dir/dank-colors.css" ] && [ "$needs_gtk_apply" -eq 1 ]; then
    backup_dir="$(mktemp -d)"
    had_gtk3_css=0
    had_gtk4_css=0
    if [ -f "$gtk3_dir/gtk.css" ]; then
      had_gtk3_css=1
      cp -f "$gtk3_dir/gtk.css" "$backup_dir/gtk3.css"
    fi
    if [ -f "$gtk4_dir/gtk.css" ]; then
      had_gtk4_css=1
      cp -f "$gtk4_dir/gtk.css" "$backup_dir/gtk4.css"
    fi

    "$shell_dir/scripts/gtk.sh" "$config_root" >/dev/null

    if [ "$had_gtk3_css" -eq 1 ]; then
      cp -f "$backup_dir/gtk3.css" "$gtk3_dir/gtk.css"
    fi
    if [ "$had_gtk4_css" -eq 1 ]; then
      cp -f "$backup_dir/gtk4.css" "$gtk4_dir/gtk.css"
    fi
    rm -rf "$backup_dir"
  fi

  chmod -R u+rwX "$cache_dir" "$gtk3_dir" "$gtk4_dir" 2>/dev/null || true
  chown -R "$username" "$cache_dir" "$gtk3_dir" "$gtk4_dir" 2>/dev/null || true
}

reset_managed_artifacts_if_force() {
  if [ "$force" -ne 1 ]; then
    return
  fi

  rm -rf "$cache_dir"
  rm -f "$gtk3_dir/settings.ini" "$gtk3_dir/gtk.css" "$gtk3_dir/dank-colors.css"
  rm -f "$gtk4_dir/settings.ini" "$gtk4_dir/gtk.css" "$gtk4_dir/dank-colors.css"
}

seed_path "$seed_home/.config/niri" "$home_dir/.config/niri"
seed_path "$seed_home/.config/DankMaterialShell" "$home_dir/.config/DankMaterialShell"
seed_path "$seed_home/.local/state/DankMaterialShell/session.json" "$home_dir/.local/state/DankMaterialShell/session.json"
seed_path "$seed_home/Pictures/Wallpapers/gruvbox_astro.jpg" "$home_dir/Pictures/Wallpapers/gruvbox_astro.jpg"

reset_managed_artifacts_if_force
load_dms_settings
bootstrap_dms_theme_if_missing

for gtk_dir in "$gtk3_dir" "$gtk4_dir"; do
  mkdir -p "$gtk_dir"
  settings_file="$gtk_dir/settings.ini"
  ensure_gtk_setting "$settings_file" "gtk-icon-theme-name" "$icon_theme"
  ensure_gtk_setting "$settings_file" "gtk-cursor-theme-name" "$cursor_theme"
  ensure_gtk_setting "$settings_file" "gtk-cursor-theme-size" "$cursor_size"
  chmod -R u+rwX "$gtk_dir" 2>/dev/null || true
  chown -R "$username" "$gtk_dir" 2>/dev/null || true
done
