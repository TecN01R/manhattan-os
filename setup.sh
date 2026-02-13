#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sudo ./setup.sh [options]

Destructive clean-install helper for this flake.
It will wipe the target disk, recreate this layout, generate hardware config,
copy this repo into target /etc/nixos, and optionally run nixos-install.

Default recreated layout:
  - GPT disk
  - p1: 1 GiB EFI System Partition (FAT32, label EFI)
  - p2: remaining space ext4 root (label root)

Options:
  --disk <path>      Target disk (default: /dev/nvme0n1)
  --mount <path>     Mount root path (default: /mnt)
  --repo <path>      Repo root to copy to target /etc/nixos
                     (default: directory containing this script)
  --host <name>      Flake host name (default: manhattanos)
  --install          Run nixos-install after preparing target
  --yes              Skip interactive WIPE confirmation prompt
  -h, --help         Show this help
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
}

unmount_source() {
  local src="$1"
  while true; do
    local target
    target="$(findmnt -rn -S "$src" -o TARGET 2>/dev/null | head -n1 || true)"
    if [[ -z "$target" ]]; then
      break
    fi
    umount "$target"
  done
}

DISK="/dev/nvme0n1"
MOUNT_ROOT="/mnt"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_NAME="manhattanos"
INSTALL_USER="kpmcdole"
RUN_INSTALL=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disk)
      DISK="$2"
      shift 2
      ;;
    --mount)
      MOUNT_ROOT="$2"
      shift 2
      ;;
    --repo)
      REPO_ROOT="$2"
      shift 2
      ;;
    --host)
      HOST_NAME="$2"
      shift 2
      ;;
    --install)
      RUN_INSTALL=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "error: run as root (sudo)." >&2
  exit 1
fi

for cmd in lsblk wipefs sfdisk mkfs.fat mkfs.ext4 mount mkdir cp git nixos-generate-config findmnt umount swapoff; do
  require_cmd "$cmd"
done

if [[ ! -b "$DISK" ]]; then
  echo "error: disk does not exist: $DISK" >&2
  exit 1
fi

if [[ ! -f "$REPO_ROOT/flake.nix" ]]; then
  echo "error: repo root missing flake.nix: $REPO_ROOT" >&2
  exit 1
fi

part_sep=""
if [[ "$DISK" =~ [0-9]$ ]]; then
  part_sep="p"
fi
EFI_PART="${DISK}${part_sep}1"
ROOT_PART="${DISK}${part_sep}2"

echo "Target disk: $DISK"
echo "EFI part:    $EFI_PART"
echo "Root part:   $ROOT_PART"
echo "Mount root:  $MOUNT_ROOT"
echo "Repo source: $REPO_ROOT"
echo
lsblk -e7 -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$DISK" || true
echo

echo "WARNING: this will WIPE ALL DATA on $DISK."
if [[ $ASSUME_YES -ne 1 ]]; then
  read -r -p "Type WIPE to continue: " confirm
  if [[ "$confirm" != "WIPE" ]]; then
    echo "aborted."
    exit 1
  fi
fi

swapoff -a || true
unmount_source "$EFI_PART"
unmount_source "$ROOT_PART"
umount "$MOUNT_ROOT/boot" 2>/dev/null || true
umount "$MOUNT_ROOT" 2>/dev/null || true

wipefs -af "$DISK"
sfdisk --delete "$DISK" || true

sfdisk "$DISK" <<'PARTITION_TABLE'
label: gpt
first-lba: 4096

,1GiB,U
,,L
PARTITION_TABLE

if command -v udevadm >/dev/null 2>&1; then
  udevadm settle
fi

mkfs.fat -F 32 -n EFI "$EFI_PART"
mkfs.ext4 -F -L root "$ROOT_PART"

mkdir -p "$MOUNT_ROOT"
mount "$ROOT_PART" "$MOUNT_ROOT"
mkdir -p "$MOUNT_ROOT/boot"
mount "$EFI_PART" "$MOUNT_ROOT/boot"

nixos-generate-config --root "$MOUNT_ROOT"
generated_hw="$(mktemp)"
cp "$MOUNT_ROOT/etc/nixos/hardware-configuration.nix" "$generated_hw"

mkdir -p "$MOUNT_ROOT/etc/nixos"
find "$MOUNT_ROOT/etc/nixos" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$REPO_ROOT"/. "$MOUNT_ROOT/etc/nixos/"
if [[ ! -d "$MOUNT_ROOT/etc/nixos/.git" ]]; then
  git -C "$MOUNT_ROOT/etc/nixos" init >/dev/null
  src_origin="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$src_origin" ]]; then
    git -C "$MOUNT_ROOT/etc/nixos" remote add origin "$src_origin" >/dev/null 2>&1 || true
  fi
fi
cp "$generated_hw" "$MOUNT_ROOT/etc/nixos/hardware-configuration.nix"
rm -f "$generated_hw"

echo
echo "Prepared target at: $MOUNT_ROOT/etc/nixos"
echo "Hardware config updated at: $MOUNT_ROOT/etc/nixos/hardware-configuration.nix"

if [[ $RUN_INSTALL -eq 1 ]]; then
  require_cmd nixos-enter

  echo
  echo "Running nixos-install..."
  if [[ "$MOUNT_ROOT" == "/mnt" ]]; then
    nixos-install --flake "$MOUNT_ROOT/etc/nixos#$HOST_NAME"
  else
    nixos-install --root "$MOUNT_ROOT" --flake "$MOUNT_ROOT/etc/nixos#$HOST_NAME"
  fi

  echo
  if nixos-enter --root "$MOUNT_ROOT" -c "id -u '$INSTALL_USER' >/dev/null 2>&1"; then
    echo "Set password for '$INSTALL_USER':"
    nixos-enter --root "$MOUNT_ROOT" -c "passwd '$INSTALL_USER'"
  else
    echo "warning: user '$INSTALL_USER' not found in target, skipping user password prompt." >&2
  fi
else
  echo
  echo "Next command:"
  if [[ "$MOUNT_ROOT" == "/mnt" ]]; then
    echo "  nixos-install --flake $MOUNT_ROOT/etc/nixos#$HOST_NAME"
  else
    echo "  nixos-install --root $MOUNT_ROOT --flake $MOUNT_ROOT/etc/nixos#$HOST_NAME"
  fi
fi
