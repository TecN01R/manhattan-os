{ config, lib, pkgs, ... }:

let
  cfg = config.manhattan.nvidia;

  cpuLowPowerCapScript = ./scripts/cpu-low-power-cap.sh;
  cpuLowPowerCap = "${pkgs.bash}/bin/bash ${cpuLowPowerCapScript}";

  gpuPowerProfileScript = ./scripts/gpu-power-profile.sh;
  gpuPowerProfile = "${pkgs.bash}/bin/bash ${gpuPowerProfileScript}";

  refreshRatePowerProfileScript = ./scripts/refresh-rate-power-profile.sh;
  refreshRatePowerProfile = "${pkgs.bash}/bin/bash ${refreshRatePowerProfileScript}";
in
{
  options.manhattan.nvidia = {
    enable = lib.mkEnableOption "NVIDIA drivers";
    cpuLowPowerCap.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable cpu-low-power-cap units.";
    };
    gpuPowerProfile.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GPU power profile toggle (power-saver disables NVIDIA).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    powerManagement.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      dynamicBoost.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    systemd.services = lib.mkIf cfg.cpuLowPowerCap.enable {
      cpu-low-power-cap = {
        description = "Adjust CPU and NVIDIA for power profile";
        after = [ "tuned-ppd.service" "tuned.service" ];
        unitConfig.StartLimitIntervalSec = "0";
        path = [ pkgs.coreutils pkgs.power-profiles-daemon ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = "10s";
          CPUAffinity = "0";
          ExecStart = cpuLowPowerCap;
        };
      };
    };

    systemd.paths = lib.mkIf cfg.cpuLowPowerCap.enable {
      cpu-low-power-cap = {
        wantedBy = [ "multi-user.target" ];
        unitConfig.StartLimitIntervalSec = "0";
        pathConfig = {
          PathChanged = "/etc/tuned/ppd_base_profile";
          PathExists = "/etc/tuned/ppd_base_profile";
          Unit = "cpu-low-power-cap.service";
        };
      };
    };

    systemd.services = lib.mkIf cfg.gpuPowerProfile.enable {
      gpu-power-profile = {
        description = "Toggle NVIDIA GPU for power profile";
        after = [ "tuned-ppd.service" "tuned.service" ];
        unitConfig.StartLimitIntervalSec = "0";
        path = [ pkgs.coreutils pkgs.power-profiles-daemon ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = "10s";
          CPUAffinity = "0";
          ExecStart = gpuPowerProfile;
        };
      };
    };

    systemd.paths = lib.mkIf cfg.gpuPowerProfile.enable {
      gpu-power-profile = {
        wantedBy = [ "multi-user.target" ];
        unitConfig.StartLimitIntervalSec = "0";
        pathConfig = {
          PathChanged = "/etc/tuned/ppd_base_profile";
          PathExists = "/etc/tuned/ppd_base_profile";
          Unit = "gpu-power-profile.service";
        };
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
        PathChanged = "/etc/tuned/ppd_base_profile";
        PathExists = "/etc/tuned/ppd_base_profile";
        Unit = "refresh-rate-power-profile.service";
      };
    };

    services.thermald.enable = true;
    services.tuned.enable = true;
    services.tuned.ppdSupport = true;
  };
}
