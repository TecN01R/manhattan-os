{ config, lib, inputs, ... }:

let
  dmsManageSettings = false;
in
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  programs.dank-material-shell = {
    enable = true;
    enableCalendarEvents = false;
    session = {};

    niri = {
      enableKeybinds = false;
      enableSpawn = true;     # auto-start DMS when niri starts
      includes = {
        enable = true;
        override = true;
        originalFileName = "hm";
      };
    };
  } // lib.optionalAttrs dmsManageSettings {
    settings = {
      currentThemeName = "custom";
      currentThemeCategory = "registry";
      customThemeFile =
        "${config.xdg.configHome}/DankMaterialShell/themes/gruvboxMaterial/theme.json";
      registryThemeVariants = {
        gruvboxMaterial = "hard";
      };
      useFahrenheit = true;
      useAutoLocation = true;
      use24HourClock = false;
      runDmsMatugenTemplates = true;
      matugenTemplateNiri = true;
    };
  };

  home.activation.bootstrapDmsNiriDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dms_dir="${config.xdg.configHome}/niri/dms"
    mkdir -p "$dms_dir"

    if [ ! -f "$dms_dir/binds.kdl" ]; then
      cp "${inputs.dms}/core/internal/config/embedded/niri-binds.kdl" "$dms_dir/binds.kdl"
      sed -i 's/{{TERMINAL_COMMAND}}/foot/g' "$dms_dir/binds.kdl"
    fi

    if [ ! -f "$dms_dir/colors.kdl" ]; then
      cp "${inputs.dms}/core/internal/config/embedded/niri-colors.kdl" "$dms_dir/colors.kdl"
    fi

    if [ ! -f "$dms_dir/layout.kdl" ]; then
      cp "${inputs.dms}/core/internal/config/embedded/niri-layout.kdl" "$dms_dir/layout.kdl"
    fi

    if [ ! -f "$dms_dir/alttab.kdl" ]; then
      cp "${inputs.dms}/core/internal/config/embedded/niri-alttab.kdl" "$dms_dir/alttab.kdl"
    fi

    for file in outputs cursor wpblur; do
      if [ ! -f "$dms_dir/$file.kdl" ]; then
        : > "$dms_dir/$file.kdl"
      fi
    done
  '';
}
