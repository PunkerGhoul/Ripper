{ pkgs, ... }:

{
  home.file.".config/picom/picom.conf".text = ''
    backend = "xrender";
    fading = false;
    fade-delta = 10;
    fade-in-step = 0.028;
    fade-out-step = 0.03;
    active-opacity = 1.0;
    inactive-opacity = 1.0;
    opacity-rule = [
      "70:class_i = 'presel_feedback'"
    ];
    corner-radius = 10;
    rounded-corners-exclude = [
      "window_type = 'dock'",
      "window_type = 'desktop'",
      "class_g = 'Polybar'"
    ];
    use-damage = true;
    unredir-if-possible = true;
    shadow = true;
    shadow-radius = 8;
    shadow-offset-x = -3;
    shadow-offset-y = -3;
    shadow-opacity = 0.25;
    shadow-exclude = [
      "window_type = 'dock'",
      "window_type = 'desktop'",
      "class_g = 'Polybar'"
    ];
    vsync = false;
    wintypes: {
      dropdown_menu = { opacity = 1.0; };
      popup_menu = { opacity = 1.0; };
    };
  '';

  home.file.".local/bin/ripper-picom-start" = {
    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
      mkdir -p "$runtime_dir"
      log="$runtime_dir/ripper-picom.log"

      ${pkgs.procps}/bin/pkill -u "''${USER:-$(${pkgs.coreutils}/bin/id -un)}" -x picom 2>/dev/null || true

      exec ${pkgs.picom}/bin/picom --config "$HOME/.config/picom/picom.conf" >>"$log" 2>&1
    '';
    executable = true;
  };
}
