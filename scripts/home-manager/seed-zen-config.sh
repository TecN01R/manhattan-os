#!/usr/bin/env bash
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: seed-zen-config <seed_home> <home_dir> <username>" >&2
  exit 2
fi

seed_home="$1"
home_dir="$2"
username="$3"

seed_file_if_missing() {
  src="$1"
  dst="$2"

  if [ ! -L "$src" ] && [ ! -e "$src" ]; then
    return 0
  fi

  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
    chmod u+rw "$dst" 2>/dev/null || true
    chown "$username" "$dst" 2>/dev/null || true
  fi
}

seed_toolbar_pins() {
  profile_dir="$1"
  prefs_file="$profile_dir/prefs.js"

  if [ ! -f "$prefs_file" ]; then
    return 1
  fi

  state_literal="$(sed -n 's/^user_pref("browser\.uiCustomization\.state", \(.*\));$/\1/p' "$prefs_file" | tail -n 1)"
  if [ -z "$state_literal" ]; then
    return 1
  fi

  state_json="$(printf '%s\n' "$state_literal" | jq -Rr 'fromjson' 2>/dev/null || true)"
  if [ -z "$state_json" ]; then
    state_json="$(
      printf '%s\n' "$state_literal" \
        | sed -e 's/^"//' -e 's/"$//' \
        | jq -c . 2>/dev/null || true
    )"
  fi
  if [ -z "$state_json" ]; then
    return 1
  fi
  updated_state_json="$(
    printf '%s\n' "$state_json" | jq -c '
      .placements = (.placements // {}) |
      .placements["nav-bar"] = ((.placements["nav-bar"] // [])
        | if index("adguardadblocker_adguard_com-browser-action") == null then . + ["adguardadblocker_adguard_com-browser-action"] else . end
        | if index("addon_darkreader_org-browser-action") == null then . + ["addon_darkreader_org-browser-action"] else . end
      )
    ' 2>/dev/null
  )" || return 1
  updated_state_literal="$(printf '%s' "$updated_state_json" | jq -Rs . 2>/dev/null)" || return 1

  replacement_line="user_pref(\"browser.uiCustomization.state\", $updated_state_literal);"
  tmp_prefs="$prefs_file.tmp.$$"
  replaced=0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'user_pref("browser.uiCustomization.state", '*)
        if [ "$replaced" -eq 0 ]; then
          printf '%s\n' "$replacement_line" >> "$tmp_prefs"
          replaced=1
        fi
        ;;
      *)
        printf '%s\n' "$line" >> "$tmp_prefs"
        ;;
    esac
  done < "$prefs_file"

  if [ "$replaced" -eq 0 ]; then
    printf '%s\n' "$replacement_line" >> "$tmp_prefs"
  fi

  mv "$tmp_prefs" "$prefs_file"
  chmod u+rw "$prefs_file" 2>/dev/null || true
  chown "$username" "$prefs_file" 2>/dev/null || true
}

ensure_user_pref() {
  file="$1"
  key="$2"
  value="$3"
  line="user_pref(\"$key\", $value);"

  if ! grep -Fq "user_pref(\"$key\"" "$file" 2>/dev/null; then
    printf '%s\n' "$line" >> "$file"
  fi
}

ensure_extension_xpi() {
  profile_dir="$1"
  addon_id="$2"
  url="$3"
  extensions_dir="$profile_dir/extensions"
  extension_xpi="$extensions_dir/$addon_id.xpi"
  tmp_xpi="$extension_xpi.tmp.$$"

  if [ -e "$extension_xpi" ] || [ -L "$extension_xpi" ]; then
    return 0
  fi

  mkdir -p "$extensions_dir"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_xpi" "$url"; then
    rm -f "$tmp_xpi"
    echo "warning: failed to seed Zen extension $addon_id from $url" >&2
    return 0
  fi

  mv "$tmp_xpi" "$extension_xpi"
  chmod u+rw "$extension_xpi" 2>/dev/null || true
  chown "$username" "$extension_xpi" 2>/dev/null || true
}

# Seed exported extension JSON files to Downloads once for manual import.
seed_file_if_missing \
  "$seed_home/.config/zen-extension-exports/Dark-Reader-Settings.json" \
  "$home_dir/Downloads/Dark-Reader-Settings.json"
seed_file_if_missing \
  "$seed_home/.config/zen-extension-exports/AdGuard-Settings.json" \
  "$home_dir/Downloads/AdGuard-Settings.json"

# Seed Zen profile tweaks for theme wiring, default search, and selected extensions.
if [ -d "$home_dir/.zen" ]; then
  dms_zen_css="file://$home_dir/.config/DankMaterialShell/zen.css"
  while IFS= read -r -d '' profile_dir; do
    if [ ! -f "$profile_dir/prefs.js" ]; then
      continue
    fi

    chrome_dir="$profile_dir/chrome"
    user_chrome="$chrome_dir/userChrome.css"
    user_js="$profile_dir/user.js"
    toolbar_marker="$profile_dir/.nix-seed-zen-toolbar-pinned"

    if [ ! -e "$user_chrome" ] && [ ! -L "$user_chrome" ]; then
      mkdir -p "$chrome_dir"
      printf '%s\n' "@import url(\"$dms_zen_css\");" > "$user_chrome"
    elif [ -f "$user_chrome" ] && ! grep -Fq "$dms_zen_css" "$user_chrome"; then
      printf '%s\n' "@import url(\"$dms_zen_css\");" >> "$user_chrome"
    fi

    if [ ! -e "$user_js" ] && [ ! -L "$user_js" ]; then
      : > "$user_js"
    fi

    if [ -f "$user_js" ]; then
      ensure_user_pref "$user_js" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
      ensure_user_pref "$user_js" "browser.search.suggest.enabled" "true"
      ensure_user_pref "$user_js" "browser.urlbar.suggest.searches" "true"
      ensure_user_pref "$user_js" "browser.search.defaultenginename" "\"DuckDuckGo\""
      ensure_user_pref "$user_js" "browser.search.selectedEngine" "\"DuckDuckGo\""
      ensure_user_pref "$user_js" "extensions.autoDisableScopes" "0"
      chmod u+rw "$user_js" 2>/dev/null || true
      chown "$username" "$user_js" 2>/dev/null || true
    fi

    ensure_extension_xpi \
      "$profile_dir" \
      "addon@darkreader.org" \
      "https://addons.mozilla.org/en-US/firefox/downloads/latest/darkreader/latest.xpi"
    ensure_extension_xpi \
      "$profile_dir" \
      "adguardadblocker@adguard.com" \
      "https://addons.mozilla.org/en-US/firefox/downloads/latest/adguard-adblocker/latest.xpi"

    # Pin seeded extension buttons to nav-bar once per profile.
    if [ ! -e "$toolbar_marker" ] && [ ! -L "$toolbar_marker" ]; then
      if seed_toolbar_pins "$profile_dir"; then
        : > "$toolbar_marker"
        chmod u+rw "$toolbar_marker" 2>/dev/null || true
        chown "$username" "$toolbar_marker" 2>/dev/null || true
      else
        echo "warning: failed to seed Zen toolbar pins in $profile_dir" >&2
      fi
    fi

  done < <(find "$home_dir/.zen" -mindepth 1 -maxdepth 1 -type d -print0)
fi
