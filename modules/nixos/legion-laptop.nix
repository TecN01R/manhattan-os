{ config, lib, pkgs, ... }:

let
  cfg = config.manhattan.nvidia;

  cpuLowPowerCap = pkgs.writeShellScript "cpu-low-power-cap" ''
    set -euo pipefail
    shopt -s nullglob

    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.power-profiles-daemon ]}:$PATH"

    profile="$(powerprofilesctl get 2>/dev/null || true)"

    mains_found=0
    on_ac=0
    for supply in /sys/class/power_supply/*; do
      [ -d "$supply" ] || continue
      if [ -f "$supply/type" ] && [ "$(cat "$supply/type")" = "Mains" ]; then
        mains_found=1
        if [ -f "$supply/online" ]; then
          if [ "$(cat "$supply/online")" = "1" ]; then
            on_ac=1
          fi
        fi
      fi
    done
    if [ "$mains_found" = "0" ]; then
      on_ac="unknown"
    fi

    low_power=0
    if [ "$profile" = "power-saver" ]; then
      low_power=1
    fi
    if [ "$mains_found" = "1" ] && [ "$on_ac" = "0" ]; then
      low_power=1
    fi

    freq_dirs=(/sys/devices/system/cpu/cpufreq/policy*)
    if [ "''${#freq_dirs[@]}" -eq 0 ]; then
      freq_dirs=()
      for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        [ -d "$cpu_dir/cpufreq" ] && freq_dirs+=("$cpu_dir/cpufreq")
      done
    fi

    for freq_dir in "''${freq_dirs[@]}"; do
      if [ "$low_power" = "1" ]; then
        target="$(cat "$freq_dir/cpuinfo_min_freq" 2>/dev/null || true)"
      else
        target="$(cat "$freq_dir/cpuinfo_max_freq" 2>/dev/null || true)"
      fi
      [ -n "$target" ] || continue

      if [ -w "$freq_dir/scaling_max_freq" ]; then
        current="$(cat "$freq_dir/scaling_max_freq" 2>/dev/null || true)"
        if [ "$current" != "$target" ]; then
          echo "$target" > "$freq_dir/scaling_max_freq"
        fi
      fi
    done
  '';
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

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cpu-low-power-cap.service"
    '';

    systemd.services.cpu-low-power-cap = {
      description = "Cap CPU frequency on low power profile or battery";
      after = [ "power-profiles-daemon.service" "upower.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cpuLowPowerCap;
      };
    };

    systemd.timers.cpu-low-power-cap = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        Unit = "cpu-low-power-cap.service";
      };
    };
  };
}
