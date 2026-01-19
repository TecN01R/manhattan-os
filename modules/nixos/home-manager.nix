{ inputs, lib, config, ... }:

let
  normalUsers =
    lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users;
in

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  # Avoid recursion: home-manager user packages can depend on users.users.
  home-manager.useUserPackages = false;
  home-manager.extraSpecialArgs = { inherit inputs; };
  home-manager.users = lib.mapAttrs (name: user:
    let
      userDir = ../../home;
      userModule = userDir + "/${name}";
    in {
      imports = [ ../../home/common ]
        ++ lib.optional (builtins.pathExists userModule) userModule;
      home.username = name;
      home.homeDirectory = user.home or "/home/${name}";
    }
  ) normalUsers;
}
