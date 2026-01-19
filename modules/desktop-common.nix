{ config, pkgs, lib, input, ... }:

let
  zen = pkgs.wrapFirefox
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser-unwrapped
    {
      extraPolicies = {
        DisableTelemetry = true;

        # Install the same extensions you currently force-install in Firefox
        ExtensionSettings = {
          "addon@darkreader.org" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          };

          "adguardadblocker@adguard.com" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/adguard-adblocker/latest.xpi";
          };
        };
      };

      # optional: lock some prefs (same technique shown on the wiki)
      extraPrefs = lib.concatLines [
        ''lockPref("extensions.pocket.enabled", false);''
      ];
    };
in
{
  # Global Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Common “desktop-ish” stuff
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # System packages (shared / non-user-specific)
  environment.systemPackages = with pkgs; [
    zen
    git
    nano
    ptyxis
    home-manager
    dconf-editor
    gnome-tweaks
    gnome-extension-manager

    gnomeExtensions.alphabetical-app-grid
    gnomeExtensions.just-perfection
    gnomeExtensions.blur-my-shell
    gnomeExtensions.user-themes
    gnomeExtensions.hot-edge
  ];

  # GNOME Desktop
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.interface]
    color-scheme='prefer-dark'
    clock-format='12h'
    clock-show-weekday=true
    show-battery-percentage=true

    [org.gnome.shell]
    disable-extension-version-validation=true
    favorite-apps=['org.gnome.Nautilus.desktop', 'firefox.desktop', 'org.gnome.Software.desktop', 'org.gnome.Settings.desktop', 'org.gnome.Ptyxis.desktop']
    enabled-extensions=['AlphabeticalAppGrid@stuarthayhurst', 'blur-my-shell@aunetx', 'just-perfection-desktop@just-perfection', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'hotedge@jonathan.jdoda.ca']

    [org.gnome.mutter]
    dynamic-workspaces=false
    experimental-features=['scale-monitor-framebuffer','variable-refresh-rate']

    [org.gnome.desktop.wm.preferences]
    num-workspaces=4

    [org.gnome.settings-daemon.plugins.color]
    night-light-enabled=true
    night-light-schedule-automatic=true
    night-light-temperature=uint32 4700

    [org.gtk.gtk4.settings.file-chooser]
    show-hidden=true

    [org.gnome.nautilus.preferences]
    default-folder-viewer='list-view'

    [org.gnome.nautilus.list-view]
    default-visible-columns=['name', 'size', 'type', 'date_modified']

    [org.gnome.system.location]
    enabled=true

    [org.gnome.shell.weather]
    automatic-location=true
  '';

  environment.gnome.excludePackages = with pkgs; [
    epiphany
    gnome-contacts
    gnome-connections
    gnome-clocks
    gnome-maps
    gnome-calculator
    gnome-console
    decibels
    gnome-calendar
    gnome-characters
    gnome-terminal
    totem
    simple-scan
    gnome-tour
    gnome-system-monitor
    gnome-music
    geary
    yelp
  ];

  # Flatpak (module provided by nix-flatpak from flake.nix)
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  services.flatpak.packages = [
    "page.codeberg.libre_menu_editor.LibreMenuEditor"
  ];
}
