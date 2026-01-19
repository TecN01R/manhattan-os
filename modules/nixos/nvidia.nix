{ config, lib, pkgs, ... }:

let
  cfg = config.manhattan.nvidia;
in
{
  options.manhattan.nvidia.enable = lib.mkEnableOption "NVIDIA drivers and X settings";

  config = lib.mkIf cfg.enable {
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
  };
}
