{ pkgs, lib, inputs, ... }:

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
  imports = [
    inputs.niri.nixosModules.niri
  ];

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
  nixpkgs.config.allowUnfree = true;

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    i2c.enable = true;
  };

  boot = {
    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };
    initrd.verbose = false;
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "systemd.show_status=false"
      "rd.systemd.show_status=false"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
    ];
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.configurationLimit = 10;
    kernelModules = [ "i2c-dev" ];
  };

  zramSwap = {
    enable = true;
    memoryPercent = 25;
    algorithm = "lz4";
  };

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MANGOHUD = "1";
    };
    systemPackages = with pkgs; [
      zen
      git
      nano
      home-manager
      starship
      i2c-tools
      xwayland-satellite
      nautilus
      gnome-text-editor
      zip
      unzip
      ghostty
      mangohud
      fastfetch
    ];
  };

  networking.networkmanager.enable = true;

  services = {
    accounts-daemon.enable = true;
    greetd.settings.terminal = {
      vt = lib.mkForce 7;
      switch = true;
    };
    gvfs.enable = true;
    udisks2.enable = true;
    fprintd.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;
    udev.packages = with pkgs; [ openrgb ];
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/kpmcdole";
    logs = {
      save = true;
      path = "/var/lib/dms-greeter/dms-greeter.log";
    };
  };

  security.pam.services.greetd.fprintAuth = false;

  users.groups.i2c = { };

  time.timeZone = "America/New_York";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
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
  };

  programs = {
    niri = {
      enable = true;
      package = pkgs.niri; # <-- use nixpkgs build (cache.nixos.org)
    };
    gamescope.enable = true;
    starship = {
      enable = true;
      presets = [ "gruvbox-rainbow" ];
    };
  };

}
