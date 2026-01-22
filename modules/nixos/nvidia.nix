{ config, lib, ... }:

let
  cfg = config.manhattan.nvidia;
in
{
  options.manhattan.nvidia.enable = lib.mkEnableOption "NVIDIA drivers";

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

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
