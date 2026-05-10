{ config, pkgs, lib, ... }:

{
  # Expose a simple services.picom option set so users can enable/configure
  # picom in a familiar way. The base config lives in picom.conf managed via
  # Home Manager and extraArgs are passed to the binary at launch.
  services.picom = {
    enable = true;
    configFile = "${config.home.homeDirectory}/.config/picom/picom.conf";
    backend = "xrender";
    fade = false;
    fadeDelta = 10;
    fadeSteps = [ 0.028 0.03 ];
    activeOpacity = 1.0;
    inactiveOpacity = 1.0;
    menuOpacity = 1.0;
    opacityRules = [
      "70:class_i = 'presel_feedback'"
    ];
    shadow = true;
    shadowOpacity = 0.18;
    shadowOffsets = [ -2 -2 ];
    shadowExclude = [
      "window_type = 'dock'"
      "window_type = 'desktop'"
      "class_g = 'Polybar'"
    ];
    vSync = false;
    settings = {
      corner-radius = 12;
      round-borders = 1;
      rounded-corners-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'Polybar'"
      ];
      use-damage = false;
      unredir-if-possible = false;
      shadow-radius = 5;
    };
    wintypes = {
      dropdown_menu = { opacity = 1.0; };
      popup_menu = { opacity = 1.0; };
    };
    extraConfig = '''';
    extraArgs = [];
  };

  home.file.".config/picom/picom.conf" = {
    source = ./picom.conf;
  };

  home.packages = lib.mkMerge [ (config.home.packages or []) [ pkgs.picom ] ];

  home.file.".local/bin/ripper-picom-start" = {
    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
      mkdir -p "$runtime_dir"
      log="$runtime_dir/ripper-picom.log"

      ${pkgs.procps}/bin/pkill -u "''${USER:-$(${pkgs.coreutils}/bin/id -un)}" -x picom 2>/dev/null || true

      exec ${pkgs.picom}/bin/picom ${lib.concatStringsSep " " (config.services.picom.extraArgs or [])} --config "${config.services.picom.configFile}" >>"$log" 2>&1
    '';
    executable = true;
  };
}
