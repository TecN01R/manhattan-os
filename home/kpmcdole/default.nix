{ config, pkgs, lib, inputs, ... }:

let
  vscodeExtensionIds = import ./vscode-extensions.nix;
  vscodeMarketplace = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
  vscodeExtensions =
    let
      resolveExtension = extensionId:
        let
          path = lib.splitString "." extensionId;
          ext = lib.attrByPath path null vscodeMarketplace;
        in
        if ext == null then
          builtins.trace "Unknown VS Code extension: ${extensionId}" null
        else
          ext;
    in
    builtins.filter (ext: ext != null) (map resolveExtension vscodeExtensionIds);

in
{
  home.packages = with pkgs; [
    github-desktop
    blender
    godot
    steam
    caprine
    discord
    obsidian
    slack
    openrgb
    goverlay
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;
    profiles.default.extensions = vscodeExtensions;
  };

  home.activation.syncUserSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    repo_root="${config.home.homeDirectory}/GitHub/manhattan-os"; [ -d "$repo_root" ] || exit 0
    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"
    cp_if_diff(){ src="$1"; dst="$2"; mkdir -p "$(dirname "$dst")"; cmp -s "$src" "$dst" 2>/dev/null || cp "$src" "$dst"; }
    sync_pair(){ src="$1"; dst="$2"; mode="''${3:-plain}"; if [ -f "$src" ]; then
      if [ "$mode" = "json" ] && ! ${pkgs.jq}/bin/jq empty "$src" >/dev/null 2>&1; then [ -f "$dst" ] && cp_if_diff "$dst" "$src"; return 0; fi
      cp_if_diff "$src" "$dst"; return 0; fi; [ -f "$dst" ] && cp_if_diff "$dst" "$src"; }
    write_json_array(){ dst="$1"; tmp="$(mktemp)"; { echo "["; while IFS= read -r l; do [ -n "$l" ] && printf '  "%s"\n' "$l"; done; echo "]"; } > "$tmp";
      cmp -s "$tmp" "$dst" 2>/dev/null && rm -f "$tmp" || { mkdir -p "$(dirname "$dst")"; mv "$tmp" "$dst"; }; }
    code_bin="${pkgs.vscode}/bin/code"; if [ -x "$code_bin" ]; then exts="$("$code_bin" --list-extensions 2>/dev/null | sort -u || true)";
      [ -n "$exts" ] && printf '%s\n' "$exts" | write_json_array "$repo_root/home/kpmcdole/vscode-extensions.nix"; fi
    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"; state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
    while IFS='|' read -r src dst mode; do [ -n "$src" ] && sync_pair "$src" "$dst" "$mode"; done <<EOF
$config_home/Code/User/settings.json|$repo_root/home/kpmcdole/vscode-settings.json|json
$config_home/DankMaterialShell/settings.json|$repo_root/home/common/dms-settings.json|
$state_home/DankMaterialShell/session.json|$repo_root/home/kpmcdole/dms-session.json|
EOF
  '';

  programs.dank-material-shell.session = lib.importJSON ./dms-session.json;
  xdg.stateFile."DankMaterialShell/session.json".force = true;

  programs.niri.settings = {
    "spawn-at-startup" = [
      { argv = [ "code" ]; }
      { argv = [ "caprine" ]; }
      { argv = [ "zen" ]; }
    ];
    workspaces = {
      "01-social" = {
        name = "social";
        open-on-output = "eDP-1";
      };
      "02-coding" = {
        name = "coding";
        open-on-output = "eDP-1";
      };
      "99-gaming" = {
        name = "gaming";
        open-on-output = "DP-3";
      };
    };
    "window-rules" = [
      {
        matches = [
          { app-id = "^zen$"; }
          { app-id = "^Caprine$"; }
          { app-id = "^slack$"; }
        ];
        open-on-workspace = "social";
        open-focused = true;
      }
      {
        matches = [
          { app-id = "^code$"; }
          { app-id = "^github-desktop$"; }
        ];
        open-on-workspace = "coding";
        open-focused = true;
      }
      {
        matches = [
          { app-id = "^steam$"; }
          { app-id = "^discord$"; }
        ];
        open-on-workspace = "gaming";
        open-focused = true;
      }
    ];
  };


}
