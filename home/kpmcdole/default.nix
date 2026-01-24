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
    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"
    export CODE_BIN="${pkgs.vscode}/bin/code"
    ${pkgs.bash}/bin/bash ${../common/scripts/sync-files.sh} \
      "${config.home.homeDirectory}/GitHub/manhattan-os" \
      "${pkgs.jq}/bin/jq" \
      ${./scripts/sync-files.user.sh}
  '';

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
