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

  refreshRateScript = pkgs.writeShellScript "refresh-rate-ac" ''
    set -eu

    profile=""
    if [ -r /var/lib/power-profiles-daemon/state.ini ]; then
      while IFS='=' read -r key value; do
        if [ "$key" = "Profile" ]; then
          profile="$value"
          break
        fi
      done < /var/lib/power-profiles-daemon/state.ini
    fi
    [ -n "$profile" ] || profile="balanced"

    state="$XDG_RUNTIME_DIR/refresh-rate-ac.last-profile"
    [ "$profile" = "$(cat "$state" 2>/dev/null || true)" ] && exit 0

    case "$profile" in
      power-saver)
        rate="3200x2000@60.001"
        vrr="off"
        label="60Hz + VRR off"
        ;;
      *)
        rate="3200x2000@165.002"
        vrr="on"
        label="165Hz + VRR on"
        ;;
    esac

    socket=""
    i=0
    while [ "$i" -lt 100 ]; do
      for s in "$XDG_RUNTIME_DIR"/niri.wayland-*.sock; do
        [ -S "$s" ] && socket="$s" && break
      done
      [ -n "$socket" ] && break
      i=$((i + 1))
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    [ -n "$socket" ] || exit 0

    niri() { NIRI_SOCKET="$socket" /run/current-system/sw/bin/niri msg output "eDP-1" "$@"; }

    echo "refresh-rate-ac: profile=$profile rate=$rate vrr=$vrr" >&2
    niri mode "$rate"
    niri vrr "$vrr"

    printf '%s\n' "$profile" > "$state"

    ${pkgs.libnotify}/bin/notify-send -a "Refresh Rate Script" -h string:desktop-entry:dms \
      -i video-display "Display profile changed" "eDP-1: $label" || true
  '';
    # gamescopeAuto = pkgs.writeShellScriptBin "gamescope-auto" ''
    #   set -eu

    #   if [ "$#" -lt 1 ]; then
    #     echo "usage: gamescope-auto <command> [args...]" >&2
    #     exit 2
    #   fi
    #   socket="''${NIRI_SOCKET:-}"
    #   if [ -z "$socket" ] && [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
    #     for s in "$XDG_RUNTIME_DIR"/niri.wayland-*.sock; do
    #       [ -S "$s" ] || continue
    #       socket="$s"
    #       break
    #     done
    #   fi

    #   width=""
    #   height=""
    #   refresh_millihz=""

    #   if [ -n "$socket" ]; then
    #     output_json="$(NIRI_SOCKET="$socket" /run/current-system/sw/bin/niri msg --json focused-output 2>/dev/null || true)"
    #     if [ -n "$output_json" ]; then
    #       width="$(printf '%s\n' "$output_json" | ${pkgs.jq}/bin/jq -r '.modes[.current_mode].width // empty')"
    #       height="$(printf '%s\n' "$output_json" | ${pkgs.jq}/bin/jq -r '.modes[.current_mode].height // empty')"
    #       refresh_millihz="$(printf '%s\n' "$output_json" | ${pkgs.jq}/bin/jq -r '.modes[.current_mode].refresh_rate // empty')"
    #     fi
    #   fi

    #   [ -n "$width" ] || width="''${GAMESCOPE_WIDTH:-1920}"
    #   [ -n "$height" ] || height="''${GAMESCOPE_HEIGHT:-1080}"
    #   [ -n "$refresh_millihz" ] || refresh_millihz="''${GAMESCOPE_REFRESH_MILLIHZ:-60000}"

    #   refresh_hz=$(( (refresh_millihz + 500) / 1000 ))

    #   exec ${pkgs.gamescope}/bin/gamescope \
    #     -f \
    #     -W "$width" -H "$height" \
    #     -w "$width" -h "$height" \
    #     -r "$refresh_hz" \
    #     -- "$@"
    # '';


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
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":";
    };
  };

  xdg.configFile."ghostty/config".text = ''
    background-opacity = 0.95
  '';

  programs.home-manager.enable = true;

  systemd.user.services.refresh-rate-ac = {
    Unit = {
      Description = "Set refresh rate based on PPD profile";
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      ExecStart = refreshRateScript;
    };
    Install = { WantedBy = [ "default.target" ]; };
  };

  systemd.user.paths.refresh-rate-ac = {
    Unit = { Description = "Watch PPD profile for refresh rate"; };
    Path = { PathChanged = "/var/lib/power-profiles-daemon/state.ini"; };
    Install = { WantedBy = [ "default.target" ]; };
  };

  # Seed desktop configuration only when a target file/path is missing.
  home.activation.seedDesktopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    copy_if_missing() {
      src="$1"
      dst="$2"

      if [ -e "$dst" ] || [ -L "$dst" ]; then
        return 0
      fi

      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$dst")"
      ${pkgs.coreutils}/bin/cp -a "$src" "$dst"
    }

    copy_if_missing "${seedHome}/.config/niri" "${homeDir}/.config/niri"
    copy_if_missing "${seedHome}/.config/DankMaterialShell" "${homeDir}/.config/DankMaterialShell"
    copy_if_missing "${seedHome}/.local/state/DankMaterialShell/session.json" "${homeDir}/.local/state/DankMaterialShell/session.json"
    copy_if_missing "${seedHome}/Pictures/Wallpapers/gruvbox_astro.jpg" "${homeDir}/Pictures/Wallpapers/gruvbox_astro.jpg"
  '';
}
