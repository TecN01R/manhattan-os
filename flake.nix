{
  description = "Manhattan OS 15";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=v0.6.0";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-flatpak, home-manager, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
  in {
    # NixOS system config
    nixosConfigurations.legion-laptop = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        nix-flatpak.nixosModules.nix-flatpak

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kpmcdole = import ./home/kpmcdole.nix;
        }

        ./hosts/legion-laptop.nix
        ./modules/desktop-common.nix
      ];
    };

    # Home Manager config for CLI: home-manager switch --flake /etc/nixos#kpmcdole
    homeConfigurations.kpmcdole = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home/kpmcdole.nix
      ];
    };
  };
}
