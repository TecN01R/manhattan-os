# manhattan-os

NixOS flake for host `manhattanos`.

## TL;DR

Use `setup.sh` for clean installs.

```bash
sudo ./setup.sh --install
```

`setup.sh` handles disk wipe/repartition/format, mount, `nixos-generate-config`, repo copy to target `/etc/nixos`, and install.

## Script Help

```bash
./setup.sh --help
```

## Rebuild (after boot)

```bash
sudo nixos-rebuild switch --flake /etc/nixos#manhattanos
```
