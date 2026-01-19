{ config, pkgs, lib, inputs, ... }:

let
  gv = lib.hm.gvariant;

  myWallpaper = pkgs.stdenv.mkDerivation {
    pname = "custom-wallpaper";
    version = "1.0";
    src = pkgs.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/minimalistic/gruvbox_astro.jpg";
      sha256 = "sha256-YTxyI+vaC5CGQzqMm1enfPh9/1YoqNXAX7TmAscz1U0=";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/backgrounds
      cp $src $out/share/backgrounds/my-wallpaper.jpg
    '';
  };

  gruvboxGtkCustom = pkgs.stdenv.mkDerivation {
    pname = "gruvbox-gtk-theme-custom";
    version = "2025-11-15";
    src = pkgs.fetchFromGitHub {
      owner = "Fausto-Korpsvart";
      repo  = "Gruvbox-GTK-Theme";
      rev   = "578cd220b5ff6e86b078a6111d26bb20ec8c733f";
      hash  = "sha256-RXoPj/aj9OCTIi8xWatG0QpDAUh102nFOipdSIiqt7o=";
    };
    nativeBuildInputs = with pkgs; [
      sassc
      gtk-engine-murrine
      gnome-themes-extra
    ];
    installPhase = ''
      runHook preInstall
      patchShebangs .
      mkdir -p $out/share/themes
      cd themes
      ./install.sh \
        -d "$out/share/themes" \
        --name Gruvbox \
        --color dark \
        --size compact \
        --tweaks medium
      runHook postInstall
    '';
  };
in
{
  # Home Manager–level configuration
  home.username = "kpmcdole";
  home.homeDirectory = "/home/kpmcdole";

  # Import DMS
  imports = [    
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  programs.dank-material-shell = {
    enable = true;

    niri = {
      enableKeybinds = true;  # optional preset binds
      enableSpawn = true;     # auto-start DMS when niri starts
    };
  };

  # Wallpaper in your home directory
  home.file.".local/share/backgrounds/my-wallpaper.jpg".source =
    "${myWallpaper}/share/backgrounds/my-wallpaper.jpg";

  # GTK4 symlinks
  home.activation.linkGtk4Theme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    themeGtk4="${gruvboxGtkCustom}/share/themes/Gruvbox-Dark-Compact-Medium/gtk-4.0"
    dest="$HOME/.config/gtk-4.0"
    mkdir -p "$dest"
    for f in assets gtk.css gtk-dark.css; do
      src="$themeGtk4/$f"
      if [ -e "$src" ]; then
        ln -sfT "$src" "$dest/$f"
      fi
    done
  '';

  # Apply wallpaper + GNOME favorites + weather + night light via dconf
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file://${myWallpaper}/share/backgrounds/my-wallpaper.jpg";
      picture-uri-dark = "file://${myWallpaper}/share/backgrounds/my-wallpaper.jpg";
    };

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

    "org/gnome/shell/extensions/user-theme" = {
      name = "Gruvbox-Dark-Compact-Medium";
    };

    "org/gnome/desktop/interface" = {
      enable-animations = true;
      gtk-theme = "Gruvbox-Dark-Compact-Medium";
      icon-theme = "Gruvbox-Plus-Dark";
    };

    ### Blur-My-Shell Extension ###
      # Root extension settings
      "org/gnome/shell/extensions/blur-my-shell" = {
        settings-version = 2;
      };

      # Appfolder
      "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
        brightness = 0.6;
        sigma = 30;
      };

      # Coverflow alt-tab
      "org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab" = {
        pipeline = "pipeline_default";
      };

      # Dash-to-dock
      "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
        blur = false;
        brightness = 0.6;
        pipeline = "pipeline_default_rounded";
        sigma = 30;
        static-blur = true;
        style-dash-to-dock = 0;
      };

      # Lockscreen
      "org/gnome/shell/extensions/blur-my-shell/lockscreen" = {
        pipeline = "pipeline_default";
      };

      # Overview
      "org/gnome/shell/extensions/blur-my-shell/overview" = {
        pipeline = "pipeline_default";
        style-components = 2;
      };

      # Panel
      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        blur = false;
        brightness = 0.6;
        pipeline = "pipeline_default";
        sigma = 30;
      };

      # Screenshot
      "org/gnome/shell/extensions/blur-my-shell/screenshot" = {
        pipeline = "pipeline_default";
      };

      # Window list
      "org/gnome/shell/extensions/blur-my-shell/window-list" = {
        brightness = 0.6;
        sigma = 30;
      };

    ### Just Perfection Extension ###
    "org/gnome/shell/extensions/just-perfection" = {
        accessibility-menu = false;
        animation = 5;
        dash-icon-size = 48;
        events-button=false;
        keyboard-layout = false;
        panel-button-padding-size = 4;
        panel-size = 24;
        quick-settings-dark-mode = false;
        ripple-box = false;
        search = false;
        support-notifier-showed-version = 34;
        window-preview-caption = false;
        workspace-switcher-size=10;
        world-clock = false;
    };
  };

  home.packages = with pkgs; [
    gruvboxGtkCustom
    gruvbox-plus-icons
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
