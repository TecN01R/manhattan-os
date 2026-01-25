{ config, pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  focusRingWidth = 1;
  myWallpaper = pkgs.fetchurl {
    url = "https://gruvbox-wallpapers.pages.dev/wallpapers/minimalistic/gruvbox_astro.jpg";
    sha256 = "sha256-YTxyI+vaC5CGQzqMm1enfPh9/1YoqNXAX7TmAscz1U0=";
  };

  gruvboxGtkCustom = pkgs.gruvbox-gtk-theme.override {
    colorVariants = [ "dark" ];
    sizeVariants = [ "compact" ];
    tweakVariants = [ "medium" ];
  };

  capitaineGruvboxWhite = pkgs.runCommand "capitaine-cursors-gruvbox-white" { } ''
    mkdir -p $out/share/icons
    cp -r \
      ${pkgs.capitaine-cursors-themed}/share/icons/Capitaine\ Cursors\ \(Gruvbox\)\ -\ White \
      $out/share/icons/
  '';

in
{
  # Import DMS
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true;
      target = "niri.service";
    };
    enableCalendarEvents = false;

    niri = {
      enableKeybinds = false;
      enableSpawn = false;    # systemd handles startup
      includes = {
        enable = true;
        override = true;
        originalFileName = "hm";
        filesToInclude = [
          "alttab"
          "binds"
          "colors"
          "cursor"
          "layout"
          "outputs"
          "wpblur"
        ];
      };
    };
  };

  programs.niri.settings = {
    input.touchpad = {
      tap = true;
      "tap-button-map" = "left-right-middle";
      "click-method" = "clickfinger";
    };
    prefer-no-csd = true;
    layout = {
      gaps = 0;
      center-focused-column = "always";
      focus-ring = {
        enable = true;
        width = focusRingWidth;
      };
      border.enable = false;
    };
    overview = {
      zoom = 0.6;
    };
    "hotkey-overlay" = {
      "skip-at-startup" = true;
    };
    "window-rules" = [
      {
        matches = [ ];
        excludes = [ ];
        geometry-corner-radius = {
          top-left = 8.0;
          top-right = 8.0;
          bottom-right = 8.0;
          bottom-left = 8.0;
        };
        clip-to-geometry = true;
      }
    ];
  };

  # Wallpaper in your home directory
  home.file.".local/share/backgrounds/gruvbox-astronaut.jpg".source = myWallpaper;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  home.pointerCursor = {
    package = capitaineGruvboxWhite;
    name = "Capitaine Cursors (Gruvbox) - White";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
  home.file.${config.xresources.path}.force = true;

  gtk = {
    enable = true;
    theme = {
      name = "Gruvbox-Dark-Compact-Medium";
      package = gruvboxGtkCustom;
    };
    iconTheme = {
      name = "Gruvbox-Plus-Dark";
      package = pkgs.gruvbox-plus-icons;
    };
  };

  xdg.configFile."gtk-4.0/gtk.css" = {
    text = "";
    force = true;
  };

  xdg.configFile."DankMaterialShell/themes/gruvboxMaterial/theme.json" = {
    source = ./dms-themes/gruvboxMaterial/theme.json;
    force = true;
  };

  xdg.configFile."ghostty/config".text = ''
    background-opacity = 0.9
  '';

  home.activation.syncDmsState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"
    export DMS_WALLPAPER_PATH="${myWallpaper}"
    ${pkgs.bash}/bin/bash ${./scripts/sync-files.sh} \
      "${config.home.homeDirectory}/GitHub/manhattan-os" \
      "${pkgs.jq}/bin/jq" \
      ${./scripts/sync-files.common.sh}
  '';

  home.packages = with pkgs; [
    gruvboxGtkCustom
    gruvbox-plus-icons
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Required for Home Manager (like system.stateVersion for NixOS)
  home.stateVersion = "25.05";
}
