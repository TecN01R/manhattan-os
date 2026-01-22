{ config, pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  dmsShell = inputs.dms.packages.${system}.dms-shell;
  dmsShellBin = "${dmsShell}/bin/dms";
  dmsShellShare = "${dmsShell}/share/quickshell/dms";
  dmsEmbedded = "${inputs.dms}/core/internal/config/embedded";
  jq = "${pkgs.jq}/bin/jq";
  focusRingWidth = 1;
  myWallpaper = pkgs.fetchurl {
    url = "https://gruvbox-wallpapers.pages.dev/wallpapers/minimalistic/gruvbox_astro.jpg";
    sha256 = "sha256-YTxyI+vaC5CGQzqMm1enfPh9/1YoqNXAX7TmAscz1U0=";
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
    enableCalendarEvents = false;
    settings = lib.importJSON ./dms-settings.json;

    niri = {
      enableKeybinds = false;
      enableSpawn = true;     # auto-start DMS when niri starts
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
    workspaces = {
      "01-social".name = "social";
      "02-coding".name = "coding";
      "99-gaming".name = "gaming";
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
      {
        matches = [
          { app-id = "^zen$"; }
          { app-id = "^io\\.github\\.zen_browser\\.zen$"; }
          { app-id = "^Caprine$"; }
          { app-id = "^discord$"; }
          { app-id = "^com\\.discordapp\\.Discord$"; }
          { app-id = "^slack$"; }
          { app-id = "^com\\.slack\\.Slack$"; }
        ];
        open-on-workspace = "social";
        open-focused = true;
      }
      {
        matches = [
          { app-id = "^code$"; }
          { app-id = "^code-oss$"; }
          { app-id = "^com\\.visualstudio\\.code$"; }
          { app-id = "^code-url-handler$"; }
          { app-id = "^github-desktop$"; }
          { app-id = "^io\\.github\\.shiftkey\\.desktop$"; }
        ];
        open-on-workspace = "coding";
        open-focused = true;
      }
      {
        matches = [
          { app-id = "^steam$"; }
          { app-id = "^com\\.valvesoftware\\.Steam$"; }
          { app-id = "^steam_app_"; }
        ];
        open-on-workspace = "gaming";
        open-focused = true;
      }
    ];
  };

  # Wallpaper in your home directory
  home.file.".local/share/backgrounds/my-wallpaper.jpg".source = myWallpaper;

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

  home.activation.regenerateDmsMatugen = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    theme_json="${config.xdg.configHome}/DankMaterialShell/themes/gruvboxMaterial/theme.json"
    session_json="${config.xdg.stateHome}/DankMaterialShell/session.json"

    if [ ! -f "$theme_json" ]; then
      exit 0
    fi

    primary="$(${jq} -r '.dark.primary // .light.primary // empty' "$theme_json")"
    if [ -z "$primary" ] || [ "$primary" = "null" ]; then
      exit 0
    fi

    mode="dark"
    if [ -f "$session_json" ] && ${jq} -e '.isLightMode == true' "$session_json" >/dev/null 2>&1; then
      mode="light"
    fi

    export PATH="${lib.makeBinPath [ pkgs.matugen ]}:$PATH"
    ${dmsShellBin} matugen generate \
      --state-dir "${config.xdg.cacheHome}/DankMaterialShell" \
      --shell-dir "${dmsShellShare}" \
      --config-dir "${config.xdg.configHome}" \
      --kind "hex" \
      --value "$primary" \
      --mode "$mode"
  '';

  home.activation.bootstrapDmsNiriDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dms_dir="${config.xdg.configHome}/niri/dms"
    mkdir -p "$dms_dir"

    if [ ! -f "$dms_dir/binds.kdl" ]; then
      cp "${dmsEmbedded}/niri-binds.kdl" "$dms_dir/binds.kdl"
      sed -i 's/{{TERMINAL_COMMAND}}/ghostty/g' "$dms_dir/binds.kdl"
    fi

    if [ ! -f "$dms_dir/colors.kdl" ]; then
      cp "${dmsEmbedded}/niri-colors.kdl" "$dms_dir/colors.kdl"
    fi

    if [ ! -f "$dms_dir/layout.kdl" ]; then
      cp "${dmsEmbedded}/niri-layout.kdl" "$dms_dir/layout.kdl"
    fi

    if [ ! -f "$dms_dir/alttab.kdl" ]; then
      cp "${dmsEmbedded}/niri-alttab.kdl" "$dms_dir/alttab.kdl"
    fi

    for file in outputs cursor wpblur; do
      if [ ! -f "$dms_dir/$file.kdl" ]; then
        : > "$dms_dir/$file.kdl"
      fi
    done
  '';

  home.activation.seedDmsWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    session_dir="${config.xdg.stateHome}/DankMaterialShell"
    session_path="$session_dir/session.json"
    wallpaper_path="${config.home.homeDirectory}/.local/share/backgrounds/my-wallpaper.jpg"

    mkdir -p "$session_dir"

    if [ ! -f "$session_path" ]; then
      cat > "$session_path" <<'EOF'
{
  "wallpaperPath": "__WALLPAPER_PATH__",
  "configVersion": 2
}
EOF
      sed -i "s|__WALLPAPER_PATH__|$wallpaper_path|g" "$session_path"
      exit 0
    fi

    if ${jq} -e '(
      (.perMonitorWallpaper // false) == true
      or (((.monitorWallpapers // {}) | length) > 0)
      or (((.wallpaperPath // "") | length) > 0)
      or ((.perModeWallpaper // false) == true)
      or (((.wallpaperPathLight // "") | length) > 0)
      or (((.wallpaperPathDark // "") | length) > 0)
    )' "$session_path" >/dev/null 2>&1; then
      exit 0
    fi

    tmp_path="$(mktemp)"
    ${jq} \
      --arg path "$wallpaper_path" \
      '.wallpaperPath = $path | .configVersion = (.configVersion // 2)' \
      "$session_path" > "$tmp_path" && mv "$tmp_path" "$session_path"
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
