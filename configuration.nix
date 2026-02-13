# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, inputs, ... }:

let
  manhattanKernel = pkgs.cachyosKernels.linux-cachyos-bore-lto.override {
    processorOpt = "x86_64-v3";
  };

  nvidiaPowerdProfileScript = pkgs.writeShellApplication {
    name = "nvidia-powerd-profile";
    runtimeInputs = with pkgs; [
      systemd
    ];
    text = builtins.readFile ./scripts/system/nvidia-powerd-profile.sh;
  };
in
{
  nixpkgs.overlays = [
    # CachyOS kernel overlay (pinned = matches repo versions + best cache hit rate)
    inputs.nix-cachyos-kernel.overlays.pinned

    inputs.niri.overlays.niri

    (final: prev: {
      winetricks = prev.winetricks.overrideAttrs (old: rec {
        version = "20260125";
        src = prev.fetchFromGitHub {
          owner = "Winetricks";
          repo = "winetricks";
          rev = version;
          hash = "sha256-uIBVESebsH7rXnxWd/qlrZxcG7Y486PctHzcLz29HDk=";
        };
      });
    })
    # Override the display of the "systemctl --user import-environment" command in niri-session to prevent it from printing warnings about missing environment variables when run in a non-interactive context (e.g. from a display manager greeter).
    (final: prev: {
      niri-unstable = prev.niri-unstable.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          substituteInPlace $out/bin/niri-session \
            --replace "systemctl --user import-environment" \
              "if [ -t 2 ]; then systemctl --user import-environment 2>&1 | ${prev.systemd}/bin/systemd-cat -t niri-session -p warning; else systemctl --user import-environment; fi"
        '';
      });
    })
  ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

nix = {
  settings = {
    download-buffer-size = 1000000000;
    max-jobs = 5;
    cores = 24;

    substituters = lib.mkBefore [
      "https://attic.xuyh0120.win/lantian"
    ];
    trusted-public-keys = lib.mkBefore [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 3d";
  };
};

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # kernelPackages = pkgs.linuxPackages_zen;
    # kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest-x86_64-v3";
    kernelPackages = pkgs.linuxKernel.packagesFor manhattanKernel;
    kernel.sysctl = {
      "fs.file-max" = 524288;

      "vm.max_map_count" = 16777216;
      "vm.swappiness" = 100;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_bytes" = 268435456; # 256 MiB
      "vm.dirty_background_bytes" = 67108864; # 64 MiB
      "vm.dirty_writeback_centisecs" = 1500; # 15 seconds
      "vm.page-cluster" = 0;
    };
    
    plymouth.enable = true;

    # Enable "Silent boot"
    consoleLogLevel = 3;
    kernelParams = lib.mkForce [
      "quiet"
      "splash"
      "loglevel=0"
      "rd.systemd.show_status=false"
      "systemd.show_status=false"
      "rd.udev.log_level=3"
      "transparent_hugepage=madvise"
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=0"
    ];

    initrd = {
      systemd.enable = true;
      verbose = false;
      
      # ensure i915 is available *in initrd* so plymouth can run on KMS ASAP
      availableKernelModules = [ "i915" ];
      kernelModules = [ "i915" ];
    };
  
    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
  };

  networking.hostName = "manhattanos"; # Define your hostname.

  # Enable networking
  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kpmcdole = {
    isNormalUser = true;
    description = "Kevin";
    extraGroups = [ "networkmanager" "wheel" "kvm"];
    packages = with pkgs; [];
  };

  # ✅ Home Manager integration
  home-manager = {
    useGlobalPkgs = true;      # reuse system pkgs
    useUserPackages = true;    # install user packages into the user profile

    # if you want `inputs` available inside home.nix modules too:
    # extraSpecialArgs = { inherit inputs; };

    users.kpmcdole = {
      imports = [ ./home/kpmcdole.nix ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # nixpkgs.hostPlatform = {
  #   system = "x86_64-linux";
  #   gcc.arch = "x86-64-v3";
  #   gcc.tune = "raptorlake";
  # };

  # systemd.services.nix-daemon.serviceConfig = {
  #   # CPUAccounting = true;
  #   # IOAccounting = true;
  #   MemoryAccounting = true;

  #   MemoryHigh = "18G";
  #   MemoryMax  = "24G";

  #   # Nice = 10;
  #   # CPUWeight = 10;
  #   # IOWeight  = 10;

  #   # LimitNOFILE = 1048576;
  #   # OOMScoreAdjust = 200;
  # };

  systemd.oomd.enable = true;

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 25;
    algorithm = "zstd";
  };

  # Enable OpenGL and Bluetooth
  hardware =  {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 32768; # MiB => 32 GiB
      # NixOS will create/format it (mkswap) at activation time if missing.
      # It will also ensure correct permissions.
      priority = -2; # lower = used later
    }
  ];

  programs.nix-ld = {
    enable = true;
  };

  # For offloading, `modesetting` is needed additionally,
  # otherwise the X-server will be running permanently on nvidia,
  # thus keeping the GPU always on (see `nvidia-smi`).
  services.xserver.videoDrivers = [
    "modesetting"  # example for Intel iGPU; use "amdgpu" here instead if your iGPU is AMD
    "nvidia"
  ];

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
    settings = {
      cgroup_realtime_workaround = lib.mkForce false;
    };
  };


  services.udev.extraRules = ''
    ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", \
    RUN+="/bin/sh -c 'echo N > /sys/module/zswap/parameters/enabled'"
  '';

  # services.scx = {
  #   enable = true;
  #   scheduler = "scx_lavd";
  # };
  services.irqbalance.enable = true;

  hardware.nvidia = {
    # Enable power scaling
    dynamicBoost.enable = true;

    # gsp.enable = false;

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = true;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    open = true;

    # Enable the Nvidia settings menu,
	# accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # PRIME
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;  
      };
      
      intelBusId = "PCI:0@0:2:0";
      nvidiaBusId = "PCI:1@0:0:0";
    };

    # Optionally, you may need to select the appropriate driver version for your specific 
    # GPU.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  

  # Prevent nvidia-powerd from auto-starting
  systemd.services.nvidia-powerd.wantedBy = lib.mkForce [ ];

  # One-shot toggle service (PPD state file)
  systemd.services.nvidia-powerd-profile = {
    description = "Start/stop nvidia-powerd based on PPD profile";
    unitConfig = {
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe nvidiaPowerdProfileScript;
    };
    wantedBy = [ "multi-user.target" ];
  };

  # Trigger on PPD profile change
  systemd.paths.nvidia-powerd-profile = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/var/lib/power-profiles-daemon/state.ini";
      Unit = "nvidia-powerd-profile.service";
    };
  };

    
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    # variables.NIX_CFLAGS_COMPILE = "-g0";
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MANGOHUD = "1";

      # System-wide cursor defaults
      # XCURSOR_THEME = "Capitaine Cursors (Gruvbox) - White";
      # XCURSOR_SIZE = "24";
    };
    systemPackages = with pkgs; [
      git
      micro
      ripgrep
      jq
      adwaita-icon-theme
      adw-gtk3
      gruvbox-plus-icons
      capitaine-cursors-themed
      xdg-user-dirs
      xdg-user-dirs-gtk
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      starship
      power-profiles-daemon
      xwayland-satellite
      nautilus
      gnome-text-editor
      zip
      unzip
      ghostty
      mangohud
      vulkan-tools
      fastfetch
      kdePackages.qt6ct
      lsfg-vk
      android-tools
      papers
    ];
  };

  programs = {
    niri = {
      enable = true;
      package = pkgs.niri-unstable; 
    };
    starship = {
      enable = true;
      presets = [ "gruvbox-rainbow" ];
    };
    gamescope.enable = true;
    dconf.enable = true;
    dank-material-shell = {
      enable = true;
      systemd.enable = true;
      enableCalendarEvents = false;
      # package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
      
      protontricks.enable = true;
    };
  };

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";

    # Sync your user's DankMaterialShell theme with the greeter. You'll probably want this
    configHome = "/home/kpmcdole";

    # Save the logs to a file
    logs = {
      save = true; 
      path = "/tmp/dms-greeter.log";
    };
  };

  # Enable battery stuff
  powerManagement.enable = true;

  services = {
    accounts-daemon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    fprintd.enable = true;
    thermald.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;
    fstrim.enable = true;
  };

  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb; # not openrgb-with-all-plugins
  };

  systemd.services.openrgb = {
    environment = {
      XDG_CONFIG_HOME = "/var/lib/OpenRGB";
    };
    preStart = ''
      install -D -m 0644 /home/kpmcdole/.config/OpenRGB/OpenRGB.json /var/lib/OpenRGB/OpenRGB/OpenRGB.json
    '';
  };

  systemd.user.services.niri-flake-polkit.enable = false;

  # services.displayManager = {
  #   gdm = {
  #     enable = true;
  #     wayland = true;
  #   };
  #   defaultSession = "gnome";
  # };

  # services.desktopManager.gnome = {
  #   enable = true;
  #   extraGSettingsOverrides = ''
  #     [org.gnome.mutter]
  #     experimental-features=['scale-monitor-framebuffer','xwayland-native-scaling','variable-refresh-rate']
  #   '';
  # };

  # programs.xwayland.enable = true;

  # # Keep GNOME lighter for testing
  # services.gnome.core-apps.enable = false;
  # services.gnome.games.enable = false;

  
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
