{ config, pkgs, ... }:

let
  theme = "cuts";
  polybarTheme = pkgs.runCommand "polybar-theme-${theme}" {} ''
    mkdir -p $out
    cp ${./polybar-themes}/launch.sh $out/launch.sh
    cp -r ${./polybar-themes}/${theme} $out/${theme}
    chmod -R u+w $out
    find $out -name "*.sh" | xargs -r sed -i \
      -e 's|polybar-msg |${pkgs.polybarFull}/bin/polybar-msg |g' \
      -e 's|polybar -q|${pkgs.polybarFull}/bin/polybar -q|g' \
      -e 's|killall -q polybar|${pkgs.psmisc}/bin/killall -q polybar|g' \
      -e 's|pgrep -u|${pkgs.procps}/bin/pgrep -u|g' \
      -e 's|rofi -|${pkgs.rofi}/bin/rofi -|g' \
      -e 's|notify-send |${pkgs.libnotify}/bin/notify-send |g' \
      -e 's|ifconfig|${pkgs.net-tools}/bin/ifconfig|g' \
      -e 's|i3-msg |${pkgs.i3}/bin/i3-msg |g'
  '';
in
{
  home.file.".config/polybar" = {
    source = polybarTheme;
    recursive = true;
  };

  home.file.".local/bin/polybar-reload" = {
    source = pkgs.replaceVars ./polybar-reload {
      python3 = "${pkgs.python3.withPackages (ps: [ ps.xlib ])}/bin/python3";
    };
    executable = true;
  };

  services.polybar = {
    enable = true;
    package = pkgs.polybarFull;
    script = ''
      $HOME/.config/polybar/launch.sh --${theme} &
      $HOME/.local/bin/polybar-reload &
    '';
  };
}
