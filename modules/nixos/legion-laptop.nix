{ config, lib, pkgs, ... }:

let
  cfg = config.manhattan.nvidia;

  cpuLowPowerCapScript = ./scripts/cpu-low-power-cap.sh;
  cpuLowPowerCap = "${pkgs.bash}/bin/bash ${cpuLowPowerCapScript}";

  refreshRatePowerProfileScript = ./scripts/refresh-rate-power-profile.sh;
  refreshRatePowerProfile = "${pkgs.bash}/bin/bash ${refreshRatePowerProfileScript}";
in
{
  options.manhattan.nvidia.enable = lib.mkEnableOption "NVIDIA drivers";

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      dynamicBoost.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    systemd.services.cpu-low-power-cap = {
      description = "Adjust CPU and NVIDIA for power profile";
      after = [ "power-profiles-daemon.service" ];
      unitConfig.StartLimitIntervalSec = "0";
      path = [ pkgs.coreutils pkgs.power-profiles-daemon ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "10s";
        CPUAffinity = "0";
        ExecStart = cpuLowPowerCap;
      };
    };

    systemd.paths.cpu-low-power-cap = {
      wantedBy = [ "multi-user.target" ];
      unitConfig.StartLimitIntervalSec = "0";
      pathConfig = {
        PathChanged = "/var/lib/power-profiles-daemon/state.ini";
        PathExists = "/var/lib/power-profiles-daemon/state.ini";
        Unit = "cpu-low-power-cap.service";
      };
    };

    systemd.user.services.refresh-rate-power-profile = {
      description = "Adjust display refresh rate for power profile";
      wantedBy = [ "default.target" ];
      unitConfig.StartLimitIntervalSec = "0";
      path = [ pkgs.coreutils pkgs.gnugrep pkgs.power-profiles-daemon pkgs.niri ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = refreshRatePowerProfile;
      };
    };

    systemd.user.paths.refresh-rate-power-profile = {
      wantedBy = [ "default.target" ];
      unitConfig.StartLimitIntervalSec = "0";
      pathConfig = {
        PathChanged = "/var/lib/power-profiles-daemon/state.ini";
        PathExists = "/var/lib/power-profiles-daemon/state.ini";
        Unit = "refresh-rate-power-profile.service";
      };
    };
  };
}
