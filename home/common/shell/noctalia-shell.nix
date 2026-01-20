{ inputs, lib, ... }:
let
  kdl = inputs.niri.lib.kdl;
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell.enable = true;

  programs.niri.config = lib.mkAfter [
    (kdl.leaf "spawn-at-startup" [ "qs" "-c" "noctalia-shell" ])
  ];
}
