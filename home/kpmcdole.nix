{ config, pkgs, lib, inputs, ... }:

let
  homeDir = "/home/kpmcdole";
  cursorThemeName = "Capitaine Cursors (Gruvbox) - White";
  seedHome = ../seed/home/kpmcdole;
  seedRepoHome = "/etc/nixos/seed/home/kpmcdole";

  # Filter: only expose that single cursor dir from the full package
  capitaineGruvboxWhite = pkgs.runCommand "capitaine-gruvbox-white-cursor" {} ''
    mkdir -p "$out/share/icons"
    ln -s "${pkgs.capitaine-cursors-themed}/share/icons/${cursorThemeName}" \
          "$out/share/icons/${cursorThemeName}"
  '';

  refreshRateScript = pkgs.writeShellApplication {
    name = "refresh-rate-switch";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = builtins.readFile ../scripts/home-manager/refresh-rate-switch.sh;
  };
  
  seedDesktopConfigScript = pkgs.writeShellApplication {
    name = "seed-desktop-config";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
      jq
    ];
    text = builtins.readFile ../scripts/home-manager/seed-desktop-config.sh;
  };

  seedZenConfigScript = pkgs.writeShellApplication {
    name = "seed-zen-config";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      curl
      gnugrep
      gnused
      jq
    ];
    text = builtins.readFile ../scripts/home-manager/seed-zen-config.sh;
  };

  syncDesktopSeedConfigScript = pkgs.writeShellApplication {
    name = "sync-desktop-seed-config";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = builtins.readFile ../scripts/home-manager/sync-desktop-seed-config.sh;
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

  # Put user-scoped packages here (instead of systemPackages)
  home.packages = with pkgs; [
    # Keep icon assets installed; DMS manages GTK settings.ini.
    gruvbox-plus-icons
    # Keep the cursor theme installed; DMS manages the actual cursor config.
    capitaineGruvboxWhite
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

  systemd.user.services.zen-config-sync = {
    Unit = {
      Description = "Backfill Zen profile extensions and prefs";
    };
    Service = {
      Type = "oneshot";
      ExecStart = ''
        ${lib.getExe seedZenConfigScript} \
          ${lib.escapeShellArg seedRepoHome} \
          ${lib.escapeShellArg homeDir} \
          ${lib.escapeShellArg config.home.username}
      '';
    };
    Install = { WantedBy = [ "default.target" ]; };
  };

  systemd.user.timers.zen-config-sync = {
    Unit = {
      Description = "Retry Zen profile sync periodically";
    };
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "45m";
      Unit = "zen-config-sync.service";
    };
    Install = { WantedBy = [ "timers.target" ]; };
  };

  # Seed desktop configuration and keep seeded paths user-editable.
  home.activation.seedDesktopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.getExe seedDesktopConfigScript} \
      ${lib.escapeShellArg (toString seedHome)} \
      ${lib.escapeShellArg homeDir} \
      ${lib.escapeShellArg config.home.username}
  '';

  # Seed Zen profile wiring (theme/search/extensions) without overwriting existing setup.
  home.activation.seedZenConfig = lib.hm.dag.entryAfter [ "seedDesktopConfig" ] ''
    ${lib.getExe seedZenConfigScript} \
      ${lib.escapeShellArg seedRepoHome} \
      ${lib.escapeShellArg homeDir} \
      ${lib.escapeShellArg config.home.username}
  '';

  # Sync live desktop config back into seed on each activation/rebuild.
  home.activation.syncDesktopSeedConfig = lib.hm.dag.entryAfter [ "seedZenConfig" ] ''
    ${lib.getExe syncDesktopSeedConfigScript} \
      ${lib.escapeShellArg homeDir} \
      ${lib.escapeShellArg seedRepoHome} \
      ${lib.escapeShellArg config.home.username}
  '';
}
