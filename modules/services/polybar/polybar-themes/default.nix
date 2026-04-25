{ pkgs, theme, polybarPackage }:

let
  # Colour overrides – format: "#AARRGGBB" or "#RRGGBB".
  # Leave empty to keep the theme default.
  colors = {
    background     = "";
    background-alt = "";
    foreground     = "";
    foreground-alt = "#9433f5f5";
    primary        = "#6435fd";
    red            = "#ff2623";
    green          = "#10af18";
    yellow         = "#ffe81d";
  };

  colorSedArgs = pkgs.lib.concatStringsSep " " (
    pkgs.lib.mapAttrsToList
      (key: val: "-e 's|^${key} = .*|${key} = ${val}|'")
      (pkgs.lib.filterAttrs (_: val: val != "") colors)
  );
in

pkgs.runCommand "polybar-theme-${theme}" { } ''
  mkdir -p $out
  cp ${./.}/launch.sh $out/launch.sh
  cp -r ${./.}/${theme} $out/${theme}
  chmod -R u+w $out
  # Strip UTF-8 BOM from all .ini files (polybar does not support BOM)
  find $out -name "*.ini" | xargs -r sed -i '1s/^\xEF\xBB\xBF//'
  # Use pulseaudio module (works with pipewire's PA compatibility layer)
  sed -i 's|\bvolume\b|pulseaudio|g' $out/${theme}/config.ini
  ${pkgs.lib.optionalString (pkgs.lib.any (v: v != "") (pkgs.lib.attrValues colors)) ''
    sed -i ${colorSedArgs} $out/${theme}/colors.ini
  ''}
  find $out -name "*.sh" | xargs -r sed -i \
    -e 's|polybar-msg |${polybarPackage}/bin/polybar-msg |g' \
    -e 's|polybar -q|${polybarPackage}/bin/polybar -q|g' \
    -e 's|killall -q polybar|${pkgs.psmisc}/bin/killall -q polybar|g' \
    -e 's|pgrep -u|${pkgs.procps}/bin/pgrep -u|g' \
    -e 's|rofi -|${pkgs.rofi}/bin/rofi -|g' \
    -e 's|notify-send |${pkgs.libnotify}/bin/notify-send |g' \
    -e 's|ifconfig|${pkgs.net-tools}/bin/ifconfig|g' \
    -e 's|i3-msg |${pkgs.i3}/bin/i3-msg |g'
''
