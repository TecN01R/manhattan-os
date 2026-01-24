{
  description = "Manhattan OS 15";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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
        self.nixosModules.legion-laptop
      ];
      mkSystem = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = baseModules ++ extraModules;
      };
    in {
      nixosConfigurations.default = mkSystem [ ];
      nixosConfigurations.legion-laptop = mkSystem [
        { manhattan.nvidia.enable = true; }
      ];

      homeConfigurations.kpmcdole = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = { inherit inputs; };
        modules = [
          inputs.niri.homeModules.config
          ./home/common
          ./home/kpmcdole
          {
            home.username = "kpmcdole";
            home.homeDirectory = "/home/kpmcdole";
          }
        ];
      };

      nixosModules = {
        desktop = import ./modules/nixos/desktop-common.nix;
        home-manager = import ./modules/nixos/home-manager.nix;
        legion-laptop = import ./modules/nixos/legion-laptop.nix;
      };

      homeManagerModules = {
        common = import ./home/common;
      };
    };
}
