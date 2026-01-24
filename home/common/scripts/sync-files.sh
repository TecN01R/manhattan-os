#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$HOME/GitHub/manhattan-os}"
jq_bin="${2:-jq}"
shift 2 || true

if [ ! -d "$repo_root" ]; then
  exit 0
fi

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
wallpaper_path_default="${DMS_WALLPAPER_PATH:-$HOME/.local/share/backgrounds/gruvbox-astronaut.jpg}"
code_bin="${CODE_BIN:-code}"

cp_if_diff() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cmp -s "$src" "$dst" 2>/dev/null || cp "$src" "$dst"
}

write_if_diff() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && cmp -s "$src" "$dst" 2>/dev/null; then
    rm -f "$src"
  else
    mv "$src" "$dst"
  fi
}

write_json_array() {
  local dst="$1"
  local tmp=""
  tmp="$(mktemp)"
  {
    echo "["
    while IFS= read -r line; do
      [ -n "$line" ] && printf '  "%s"\n' "$line"
    done
    echo "]"
  } > "$tmp"
  write_if_diff "$tmp" "$dst"
}

sync_vscode_extensions() {
  local bin="$1"
  local dst="$2"
  local exts=""
  if [ -z "$bin" ] || [ ! -x "$bin" ]; then
    return 0
  fi
  exts="$("$bin" --list-extensions 2>/dev/null | sort -u || true)"
  if [ -n "$exts" ]; then
    printf '%s\n' "$exts" | write_json_array "$dst"
  fi
}

sync_pair() {
  local src="$1"
  local dst="$2"
  local mode="${3:-plain}"
  if [ -f "$src" ]; then
    if [ "$mode" = "json" ] && ! "$jq_bin" empty "$src" >/dev/null 2>&1; then
      [ -f "$dst" ] && cp_if_diff "$dst" "$src"
      return 0
    fi
    cp_if_diff "$src" "$dst"
    return 0
  fi
  [ -f "$dst" ] && cp_if_diff "$dst" "$src"
}

seed_wallpaper() {
  local session_path="$1"
  local wallpaper_path="${2:-$wallpaper_path_default}"
  local session_dir=""
  local tmp_path=""

  if [ -z "$wallpaper_path" ]; then
    return 0
  fi

  session_dir="$(dirname "$session_path")"
  mkdir -p "$session_dir"

  if [ ! -f "$session_path" ]; then
    cat > "$session_path" <<EOF
{
  "wallpaperPath": "$wallpaper_path",
  "configVersion": 2
}
EOF
    return 0
  fi

  if ! "$jq_bin" -e '(
    (.perMonitorWallpaper // false) == false
    and (((.monitorWallpapers // {}) | length) == 0)
    and ((.perModeWallpaper // false) == false)
    and (((.wallpaperPathLight // "") | length) == 0)
    and (((.wallpaperPathDark // "") | length) == 0)
    and (((.wallpaperPath // "") | length) == 0)
  )' "$session_path" >/dev/null 2>&1; then
    return 0
  fi

  tmp_path="$(mktemp)"
  if "$jq_bin" --arg path "$wallpaper_path" \
    '.wallpaperPath = $path | .configVersion = (.configVersion // 2)' \
    "$session_path" > "$tmp_path"; then
    write_if_diff "$tmp_path" "$session_path"
  else
    rm -f "$tmp_path"
  fi
}

process_item() {
  local item="$1"
  local action=""
  local src=""
  local dst=""
  local mode=""
  local seed=""
  IFS='|' read -r action src dst mode seed <<< "$item"
  case "$action" in
    seed-wallpaper)
      seed_wallpaper "$src" "$dst"
      ;;
    vscode-exts)
      if [ -z "$dst" ]; then
        echo "sync-files: missing destination path for: $item" >&2
        exit 1
      fi
      sync_vscode_extensions "${src:-$code_bin}" "$dst"
      ;;
    sync)
      sync_pair "$src" "$dst" "$mode"
      ;;
    *)
      echo "sync-files: unknown action '$action' for: $item" >&2
      exit 1
      ;;
  esac
}

for manifest in "$@"; do
  [ -f "$manifest" ] || continue
  SYNC_ITEMS=()
  # shellcheck source=/dev/null
  source "$manifest"
  for item in "${SYNC_ITEMS[@]}"; do
    process_item "$item"
  done
done
