# manhattan-os

Personal NixOS flake for host `manhattanos`.

## Repository Layout

- `flake.nix`, `flake.lock`: flake entrypoint and pinned inputs
- `configuration.nix`: system configuration
- `hardware-configuration.nix`: host hardware config (regenerate for reinstall/new disk)
- `home/kpmcdole.nix`: Home Manager config
- `seed/home/kpmcdole/...`: one-time seed data for Niri/DMS/wallpaper

## Disk + Mount Prep (Installer)

If partitions/filesystems already exist, you only need to mount them.

1. Identify devices/UUIDs:

```bash
lsblk -f
```

2. Mount root and EFI partition:

```bash
mount /dev/disk/by-uuid/<ROOT-UUID> /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-uuid/<EFI-UUID> /mnt/boot
```

3. Optional: enable swap (if you use a swap partition):

```bash
swapon /dev/disk/by-uuid/<SWAP-UUID>
```

If you need a quick fresh-format example (destructive, wipes data):

```bash
# example only; replace device names for your machine
mkfs.ext4 /dev/nvme0n1p2
mkfs.fat -F 32 /dev/nvme0n1p1
```

## Recreate Current Disk Layout (Destructive)

Current layout on this machine:

- Disk: `nvme0n1` (~1.8 TiB)
- Partition 1: 1 GiB EFI System Partition (`vfat`, label `EFI`, mounted at `/boot`)
- Partition 2: remaining space (`ext4`, label `root`, mounted at `/`)
- No swap partition (swap is `zram` + `/swapfile` in NixOS config)

This fully wipes and recreates that shape:

```bash
# CHANGE THIS if your target disk is different
DISK=/dev/nvme0n1

swapoff -a || true
wipefs -af "$DISK"
sfdisk --delete "$DISK"

# p1 starts at 2 MiB, size 1 GiB, type EFI
# p2 uses the rest, type Linux filesystem
sfdisk "$DISK" <<'EOF'
label: gpt
first-lba: 4096

,1GiB,U
,,L
EOF

mkfs.fat -F 32 -n EFI "${DISK}p1"
mkfs.ext4 -F -L root "${DISK}p2"

mount "${DISK}p2" /mnt
mkdir -p /mnt/boot
mount "${DISK}p1" /mnt/boot
```

After that, run `nixos-generate-config --root /mnt` and continue with install below.

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

## Niri/DMS Seed Behavior

On each Home Manager activation, this repo seeds initial user files from `seed/home/kpmcdole` only if missing:

- `~/.config/niri`
- `~/.config/DankMaterialShell`
- `~/.local/state/DankMaterialShell/session.json`
- `~/Pictures/Wallpapers/gruvbox_astro.jpg`

Existing files are never overwritten, so your edits remain user-managed.

### Reseed a File

```bash
rm -rf ~/.config/niri
sudo nixos-rebuild switch --flake /etc/nixos/manhattan-os#manhattanos
```
