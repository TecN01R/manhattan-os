{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.niri.nixosModules.niri
    inputs.home-manager.nixosModules.home-manager

    ./hardware.nix
    ../../modules/nixos/desktop-common.nix
    ../../modules/nixos/home-manager.nix
  ];

  networking.hostName = "legion-laptop";

  # System user for Kevin (normal human user)
  users.users.kpmcdole = {
    isNormalUser = true;
    description = "Kevin";
    home = "/home/kpmcdole";
    group = "kpmcdole";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.bashInteractive;
  };

  # Primary group for Kevin
  users.groups.kpmcdole = { };

  # Bootloader / kernel (host-level choice)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # X / GPU bits that are specific to this machine
  services.xserver.enable = true;
  services.xserver.excludePackages = with pkgs; [ xterm ];
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Per-machine NixOS state version
  system.stateVersion = "25.05"; # Did you read the comment?
}
