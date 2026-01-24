# Manhattan OS

Hardware-agnostic NixOS + Home Manager modules intended to be layered on top of a local machine config.

## Goals
- Keep hardware details local (disk layout, devices).
- Share UI/app defaults across machines and users.
- Allow per-user overlays via `home/<username>/default.nix`.

## How It Works
This repo exports:
- `nixosModules.desktop` (UI/app defaults, Niri, greetd)
- `nixosModules.home-manager` (Home Manager for all normal users)
- `nixosModules.nvidia` (opt-in NVIDIA support)

Your local machine still provides:
- `hardware-configuration.nix`
- a minimal `configuration.nix` with users and bootloader

The flake tries to load:
1) `./configuration.nix` (repo root), else `/etc/nixos/configuration.nix`
2) if no config exists, it falls back to `./hardware-configuration.nix` or `/etc/nixos/hardware-configuration.nix`

## Minimal local `/etc/nixos/configuration.nix`
```nix
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "manhattanos";

  users.users.kpmcdole = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  system.stateVersion = "25.11";
}
```

## Build / switch
- Default (no NVIDIA):
  ```bash
  sudo nixos-rebuild switch --flake /path/to/manhattan-os#default --impure
  ```
- NVIDIA enabled:
  ```bash
  sudo nixos-rebuild switch --flake /path/to/manhattan-os#nvidia --impure
  ```

## Pure builds (no `--impure`)
Copy or symlink local files into the repo root:
```bash
ln -s /etc/nixos/configuration.nix /path/to/manhattan-os/configuration.nix
ln -s /etc/nixos/hardware-configuration.nix /path/to/manhattan-os/hardware-configuration.nix
```
Then drop `--impure`.

## Per-user overlays
All normal users get `home/common`.
If `home/<username>/default.nix` exists, it is layered automatically.

## Settings sync
On Home Manager activation we run a small sync helper so GUI-editable files stay writable but still land in git:
- Driver: `home/common/scripts/sync-files.sh`
- Shared manifest: `home/common/scripts/sync-files.common.sh`
- Per-user manifest: `home/<username>/scripts/sync-files.user.sh`

Behavior:
- If a local file exists, it is copied into the repo (authoritative).
- If a local file is missing but a repo copy exists, it is copied into place.
- DMS wallpaper is seeded only when no wallpaper is configured (uses `DMS_WALLPAPER_PATH`).
