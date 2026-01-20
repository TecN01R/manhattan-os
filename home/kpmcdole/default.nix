{ pkgs, lib, ... }:

let
  steamWithExtest = pkgs.steam.override {
    extraEnv = {
      LD_PRELOAD = "${pkgs.pkgsi686Linux.extest}/lib/libextest.so";
    };
  };
in
{
  home.packages = with pkgs; [
    vscode
    github-desktop
    blender
    godot
    steamWithExtest
    caprine
    discord
    obsidian
    slack
  ];

  programs.mangohud = {
    enable = true;
    enableSessionWide = true;
  };

  programs.dank-material-shell.session = lib.importJSON ./dms-session.json;
}
