{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    vscode
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

  programs.dank-material-shell.session = lib.importJSON ./dms-session.json;
}
