{ inputs, ... }:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell.enable = true;

  programs.niri.settings.spawn-at-startup = [
    {
      command = [ "qs" "-c" "noctalia-shell" ];
    }
  ];
}
