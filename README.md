# manhattan-os

Personal NixOS flake for host `manhattanos`.

## Repository Layout

- `flake.nix`, `flake.lock`: flake entrypoint and pinned inputs
- `configuration.nix`: system configuration
- `hardware-configuration.nix`: host hardware config (regenerate for reinstall/new disk)
- `home/kpmcdole.nix`: Home Manager config
- `seed/home/kpmcdole/...`: one-time seed data for Niri/DMS/wallpaper

## Fresh Install (From NixOS Installer)

Assumes your target root is mounted at `/mnt` and `/boot` is mounted at `/mnt/boot`.

1. Generate hardware config for the install target:

```bash
nixos-generate-config --root /mnt
```

2. Clone this repo into the target system:

```bash
git clone https://github.com/TecN01R/manhattan-os.git /mnt/etc/nixos/manhattan-os
```

3. Replace repo hardware config with the one just generated:

```bash
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/manhattan-os/hardware-configuration.nix
```

4. Install using the flake host output:

```bash
nixos-install --flake /mnt/etc/nixos/manhattan-os#manhattanos
```

5. Reboot:

```bash
reboot
```

## Rebuild / Switch On Installed System

If repo is cloned to `/etc/nixos/manhattan-os`:

```bash
sudo nixos-rebuild switch --flake /etc/nixos/manhattan-os#manhattanos
```

## One-Time Niri/DMS Seed Behavior

On first Home Manager activation, this repo seeds initial user files from `seed/home/kpmcdole` only if missing:

- `~/.config/niri`
- `~/.config/DankMaterialShell`
- `~/.local/state/DankMaterialShell/session.json`
- `~/Pictures/Wallpapers/gruvbox_astro.jpg`

After seeding, marker file is created:

`~/.local/state/manhattan-os/seed-v1`

As long as that marker exists, seeding is skipped and your files remain user-managed.

### Force Reseed

```bash
rm ~/.local/state/manhattan-os/seed-v1
sudo nixos-rebuild switch --flake /etc/nixos/manhattan-os#manhattanos
```
