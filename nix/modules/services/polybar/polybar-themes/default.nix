{ pkgs, theme, polybarPackage, logoutScript }:

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
  # Ripper restarts all bars as one unit on XRandR changes; Polybar's native
  # per-instance reload can leave the bottom bar missing during VMware resizes.
  find $out -name "*.ini" | xargs -r sed -i 's|^screenchange-reload = .*|screenchange-reload = false|'
  sed -i '/^wm-name = /d' $out/${theme}/config.ini
  sed -i \
    -e '/^\[bar\/top\]$/a wm-name = ripper-polybar-top' \
    -e '/^\[bar\/bottom\]$/a wm-name = ripper-polybar-bottom' \
    $out/${theme}/config.ini
  # Use pulseaudio module (works with pipewire's PA compatibility layer)
  sed -i 's|\bvolume\b|pulseaudio|g' $out/${theme}/config.ini
  # The upstream theme pins a machine-specific sink, which makes the displayed
  # percentage stale or wrong on VMs. Let polybar follow the default sink.
  sed -i '/^sink = /d' $out/${theme}/modules.ini
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
    -e 's|ans=\$(confirm_exit &)|ans=$(confirm_exit)|g' \
    -e 's|$HOME/.config/scripts/lock|$HOME/.config/i3/scripts/lock|g' \
    -e 's@"\$DESKTOP_SESSION" == "i3"@"\$DESKTOP_SESSION" == "i3" || "\$DESKTOP_SESSION" == "ripper"@g' \
    -e 's|i3-msg exit|${logoutScript}|g' \
    -e 's|i3-msg |${pkgs.i3}/bin/i3-msg |g'
  find $out -type f \( -name "*.sh" -o -name "checkupdates" \) -exec chmod +x {} +
  chmod +x $out/launch.sh
''
