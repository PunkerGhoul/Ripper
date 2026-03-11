{ config, pkgs, ... }:

let
  theme = "cuts";

  featherFont   = import ./feather-font.nix { inherit pkgs; };
  polybarReload = import ./polybar-reload   { inherit pkgs; };
  polybarTheme  = import ./polybar-themes   { inherit pkgs theme; };
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
