{ config, pkgs, ... }:

let
  theme = "cuts";

  # Colour overrides – format: "#AARRGGBB" or "#RRGGBB".
  # Leave empty to keep the theme default.
  colors = {
    background     = "";
    background-alt = "";
    foreground     = "";
    foreground-alt = "";
    primary        = "";
    red            = "";
    green          = "";
    yellow         = "";
  };

  # Only generate sed args for keys that have a non-empty value.
  colorSedArgs = pkgs.lib.concatStringsSep " " (
    pkgs.lib.mapAttrsToList
      (key: val: "-e 's|^${key} = .*|${key} = ${val}|'")
      (pkgs.lib.filterAttrs (_: val: val != "") colors)
  );

  featherFont = pkgs.stdenvNoCC.mkDerivation {
    pname = "feather-font";
    version = "unstable";
    src = pkgs.fetchurl {
      url = "https://github.com/adi1090x/polybar-themes/raw/master/fonts/feather.ttf";
      sha256 = "0n01h49l49n8n1m8g1f6dhyn6cc1d82jxmpjzs5ydsrbmxi83b4h";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp $src $out/share/fonts/truetype/feather.ttf
    '';
  };

  polybarReload = pkgs.runCommandCC "polybar-reload" {} ''
    mkdir -p $out/bin
    $CC ${pkgs.replaceVars ./polybar-reload.c {
      polybarMsg = "${pkgs.polybarFull}/bin/polybar-msg";
    }} \
      -I${pkgs.xorgproto}/include \
      -I${pkgs.libX11.dev}/include \
      -I${pkgs.libXrender.dev}/include \
      -I${pkgs.libXrandr.dev}/include \
      -L${pkgs.libX11}/lib \
      -L${pkgs.libXrandr}/lib \
      -lX11 -lXrandr \
      -o $out/bin/polybar-reload
  '';

  polybarTheme = pkgs.runCommand "polybar-theme-${theme}" {} ''
    mkdir -p $out
    cp ${./polybar-themes}/launch.sh $out/launch.sh
    cp -r ${./polybar-themes}/${theme} $out/${theme}
    chmod -R u+w $out
    ${pkgs.lib.optionalString (pkgs.lib.any (v: v != "") (pkgs.lib.attrValues colors)) ''
      sed -i ${colorSedArgs} $out/${theme}/colors.ini
    ''}
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
  home.packages = [
    pkgs.nerd-fonts.iosevka
    pkgs.nerd-fonts.symbols-only
  ];

  home.file.".config/fontconfig/conf.d/99-feather.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <dir>${featherFont}/share/fonts/truetype</dir>
    </fontconfig>
  '';

  home.file.".config/polybar" = {
    source = polybarTheme;
    recursive = true;
  };

  home.file.".local/bin/polybar-reload" = {
    source = "${polybarReload}/bin/polybar-reload";
    executable = true;
  };

  services.polybar = {
    enable = true;
    package = pkgs.polybarFull;
    script = ''
      ${pkgs.fontconfig}/bin/fc-cache
      $HOME/.config/polybar/launch.sh --${theme} &
      $HOME/.local/bin/polybar-reload &
    '';
  };
}
