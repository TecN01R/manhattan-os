{ config, pkgs, lib, ... }:

let

in
{
  # Home Manager–level configuration
  home.username = "kpmcdole";
  home.homeDirectory = "/home/kpmcdole";

  # Apply wallpaper + GNOME favorites + weather + night light via dconf
  dconf.settings = {
    "org/gnome/shell" = {
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "caprine.desktop"
        "discord.desktop"
        "steam.desktop"
        "obsidian.desktop"
        "code.desktop"
        "github-desktop.desktop"
        "org.godotengine.Godot4.5.desktop"
        "blender.desktop"
        "org.gnome.Software.desktop"
        "org.gnome.Settings.desktop"
        "net.nokyan.Resources.desktop"
        "org.gnome.Ptyxis.desktop"
      ];
    };
  };

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

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Required for Home Manager (like system.stateVersion for NixOS)
  home.stateVersion = "25.05";
}
