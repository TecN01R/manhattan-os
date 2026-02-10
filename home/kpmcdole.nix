{ config, pkgs, lib, inputs, ... }:

let
  homeDir = "/home/kpmcdole";
  cursorThemeName = "Capitaine Cursors (Gruvbox) - White";
  seedHome = ../seed/home/kpmcdole;

  # Filter: only expose that single cursor dir from the full package
  capitaineGruvboxWhite = pkgs.runCommand "capitaine-gruvbox-white-cursor" {} ''
    mkdir -p "$out/share/icons"
    ln -s "${pkgs.capitaine-cursors-themed}/share/icons/${cursorThemeName}" \
          "$out/share/icons/${cursorThemeName}"
  '';

  gtkThemeName  = "Gruvbox-Dark-Compact-Medium";
  iconThemeName = "Gruvbox-Plus-Dark";

  gtkThemePkg = pkgs.gruvbox-gtk-theme.override {
    colorVariants = [ "dark" ];
    sizeVariants  = [ "compact" ];
    tweakVariants = [ "medium" ];
  };

  refreshRateScript = pkgs.writeShellApplication {
    name = "refresh-rate-switch";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = builtins.readFile ../scripts/home-manager/refresh-rate-switch.sh;
  };

  # Add this to home.packages if you want the wrapper available in PATH.
  gamescopeAuto = pkgs.writeShellApplication {
    name = "gamescope-auto";
    runtimeInputs = with pkgs; [
      gamescope
      jq
    ];
    text = builtins.readFile ../scripts/home-manager/gamescope-auto.sh;
  };

  seedDesktopConfigScript = pkgs.writeShellApplication {
    name = "seed-desktop-config";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = builtins.readFile ../scripts/home-manager/seed-desktop-config.sh;
  };


in
{
  home.username = "kpmcdole";
  home.homeDirectory = homeDir;

  # MUST match your NixOS stateVersion era (doesn't have to equal, but keep sane)
  home.stateVersion = "25.11";

  # Setup user folders (Documents, Downloads, etc...)
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  home.pointerCursor = {
    package = capitaineGruvboxWhite;
    name = cursorThemeName;
    size = 24;

    gtk.enable = true;
    x11.enable = true;
  };

  # (Optional) Some apps/toolkits still consult these env vars.
  home.sessionVariables = {
    XCURSOR_THEME = cursorThemeName;
    XCURSOR_SIZE = "24";
  };

  gtk = {
    enable = true;

    theme = {
      # Must match the directory name under .../share/themes
      name = gtkThemeName;

      # This is where the variant customization belongs
      package = gtkThemePkg;
    };

    iconTheme = {
      name = iconThemeName;
      package = pkgs.gruvbox-plus-icons;
    };
  };

  # Put user-scoped packages here (instead of systemPackages)
  home.packages = with pkgs; [
    github-desktop
    blender
    godot
    caprine
    vesktop
    obsidian
    slack
    goverlay
    openrgb
    lsfg-vk-ui
    claude-code
  ];

  programs.vscode = {
    enable = true;
    # package = pkgs.vscode;
    mutableExtensionsDir = true;
  };

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";

    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":";
    };
  };

  xdg.configFile."ghostty/config".text = ''
    background-opacity = 0.95
  '';

  programs.home-manager.enable = true;

  systemd.user.services.refresh-rate-switch = {
    Unit = {
      Description = "Set refresh rate based on PPD profile";
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe refreshRateScript;
    };
    Install = { WantedBy = [ "default.target" ]; };
  };

  systemd.user.paths.refresh-rate-switch = {
    Unit = { Description = "Watch PPD profile for refresh rate"; };
    Path = { PathChanged = "/var/lib/power-profiles-daemon/state.ini"; };
    Install = { WantedBy = [ "default.target" ]; };
  };

  # Seed desktop configuration and keep seeded paths user-editable.
  home.activation.seedDesktopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.getExe seedDesktopConfigScript} \
      ${lib.escapeShellArg (toString seedHome)} \
      ${lib.escapeShellArg homeDir} \
      ${lib.escapeShellArg config.home.username}
  '';
}
