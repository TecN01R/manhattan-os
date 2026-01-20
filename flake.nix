{
  description = "Manhattan OS 15";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=v0.6.0";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      localConfig =
        if builtins.pathExists ./configuration.nix then ./configuration.nix
        else if builtins.pathExists /etc/nixos/configuration.nix then /etc/nixos/configuration.nix
        else null;
      hardwareConfig =
        if builtins.pathExists ./hardware-configuration.nix then ./hardware-configuration.nix
        else if builtins.pathExists /etc/nixos/hardware-configuration.nix then /etc/nixos/hardware-configuration.nix
        else null;
      localModules =
        if localConfig != null then [ localConfig ]
        else if hardwareConfig != null then [ hardwareConfig ]
        else throw "No configuration.nix or hardware-configuration.nix found. Copy/symlink it into the repo root, or use /etc/nixos/ with --impure.";
      baseModules = localModules ++ [
        self.nixosModules.desktop
        self.nixosModules.home-manager
        self.nixosModules.nvidia
      ];
      mkSystem = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = baseModules ++ extraModules;
      };
    in {
      nixosConfigurations.default = mkSystem [ ];
      nixosConfigurations.nvidia = mkSystem [
        { manhattan.nvidia.enable = true; }
      ];

      nixosModules = {
        desktop = import ./modules/nixos/desktop-common.nix;
        home-manager = import ./modules/nixos/home-manager.nix;
        nvidia = import ./modules/nixos/nvidia.nix;
      };

      homeManagerModules = {
        common = import ./home/common;
      };
    };
}
