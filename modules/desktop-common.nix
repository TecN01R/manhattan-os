{ config, pkgs, ... }:

let 
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

  wallpaperPath = "${myWallpaper}/share/backgrounds/my-wallpaper.jpg";

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
    git
    nano
    ptyxis
    home-manager
    dconf-editor
    gnome-tweaks
    gnome-extension-manager
    resources

    gruvboxGtkCustom
    gruvbox-plus-icons

    gnomeExtensions.alphabetical-app-grid
    gnomeExtensions.just-perfection
    gnomeExtensions.blur-my-shell
    gnomeExtensions.user-themes
    gnomeExtensions.hot-edge
  ];

  environment.etc."gtk-4.0/gtk.css".source =
    "${gruvboxGtkCustom}/share/themes/Gruvbox-Dark-Compact-Medium/gtk-4.0/gtk.css";

  environment.etc."gtk-4.0/gtk-dark.css".source =
    "${gruvboxGtkCustom}/share/themes/Gruvbox-Dark-Compact-Medium/gtk-4.0/gtk-dark.css";

  # If the theme has an assets directory:
  environment.etc."gtk-4.0/assets".source =
    "${gruvboxGtkCustom}/share/themes/Gruvbox-Dark-Compact-Medium/gtk-4.0/assets";

  # Firefox
  programs.firefox = {
    enable = true;

    policies = {
      ExtensionSettings = {

        # Dark Reader
        "addon@darkreader.org" = {
          installation_mode = "force_installed";
          install_url =
            "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
        };

        # AdGuard AdBlocker
        "adguardadblocker@adguard.com" = {
          installation_mode = "force_installed";
          install_url =
            "https://addons.mozilla.org/firefox/downloads/latest/adguard-adblocker/latest.xpi";
        };
      };
    };
  };

  # GNOME Desktop
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.interface]
    color-scheme='prefer-dark'
    clock-format='12h'
    clock-show-weekday=true
    show-battery-percentage=true
    gtk-theme='Gruvbox-Dark-Compact-Medium'
    icon-theme='Gruvbox-Plus-Dark'

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

    [org.gnome.shell.extensions.user-theme]
    name='Gruvbox-Dark-Compact-Medium'

    ### Blur-My-Shell Extension ###

    [org.gnome.shell.extensions.blur-my-shell]
    settings-version=2

    [org.gnome.shell.extensions.blur-my-shell.appfolder]
    brightness=0.6
    sigma=30

    [org.gnome.shell.extensions.blur-my-shell.coverflow-alt-tab]
    pipeline='pipeline_default'

    [org.gnome.shell.extensions.blur-my-shell.dash-to-dock]
    blur=false
    brightness=0.6
    pipeline='pipeline_default_rounded'
    sigma=30
    static-blur=true
    style-dash-to-dock=0

    [org.gnome.shell.extensions.blur-my-shell.lockscreen]
    pipeline='pipeline_default'

    [org.gnome.shell.extensions.blur-my-shell.overview]
    pipeline='pipeline_default'
    style-components=2

    [org.gnome.shell.extensions.blur-my-shell.panel]
    blur=false
    brightness=0.6
    pipeline='pipeline_default'
    sigma=30

    [org.gnome.shell.extensions.blur-my-shell.screenshot]
    pipeline='pipeline_default'

    [org.gnome.shell.extensions.blur-my-shell.window-list]
    brightness=0.6
    sigma=30

    ### Just Perfection Extension ###

    [org.gnome.shell.extensions.just-perfection]
    accessibility-menu=false
    animation=5
    dash-icon-size=48
    events-button=false
    keyboard-layout=false
    panel-button-padding-size=4
    panel-size=24
    quick-settings-dark-mode=false
    ripple-box=false
    search=false
    support-notifier-showed-version=34
    window-preview-caption=false
    workspace-switcher-size=10
    world-clock=false

    [org.gnome.desktop.background]
    picture-uri='file://${wallpaperPath}'
    picture-uri-dark='file://${wallpaperPath}'
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
