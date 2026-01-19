{ pkgs, ... }:

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
  ];
}
