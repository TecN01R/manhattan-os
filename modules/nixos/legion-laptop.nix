{ config, lib, pkgs, ... }:

let
  cfg = config.manhattan.nvidia;

  powersaveCapScript = ./scripts/powersave-cap.sh;
  powersaveCap = "${pkgs.bash}/bin/bash ${powersaveCapScript}";

  refreshRatePowerProfileScript = ./scripts/refresh-rate-power-profile.sh;
  refreshRatePowerProfile = "${pkgs.bash}/bin/bash ${refreshRatePowerProfileScript}";
in
{
  options.manhattan.nvidia = {
    enable = lib.mkEnableOption "NVIDIA drivers";
    powersaveCap.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable powersave-cap units.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

    powerManagement.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      dynamicBoost.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    systemd.services = lib.mkMerge [
      (lib.mkIf cfg.powersaveCap.enable {
        powersave-cap = {
          description = "Adjust psys limits for power profile";
          after = [ "tuned-ppd.service" "tuned.service" ];
          unitConfig.StartLimitIntervalSec = "0";
          path = [ pkgs.coreutils pkgs.power-profiles-daemon ];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "10s";
            CPUAffinity = "0";
            ExecStart = powersaveCap;
          };
        };
      })
      (lib.mkIf config.hardware.nvidia.dynamicBoost.enable {
        nvidia-powerd = {
          unitConfig.ConditionPathExists = "/dev/nvidia0";
        };
      })
    ];

    systemd.paths = lib.mkMerge [
      (lib.mkIf cfg.powersaveCap.enable {
        powersave-cap = {
          wantedBy = [ "multi-user.target" ];
          unitConfig.StartLimitIntervalSec = "0";
          pathConfig = {
            PathChanged = "/etc/tuned/ppd_base_profile";
            PathExists = "/etc/tuned/ppd_base_profile";
            Unit = "powersave-cap.service";
          };
        };
      })
    ];

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
