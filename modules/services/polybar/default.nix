{ config, pkgs, ... }:

{
  home.file.".config/polybar" = {
    source = ./polybar-themes;
    recursive = true;
  };

  home.file.".local/bin/polybar-reload" = {
    source = ./polybar-reload;
    executable = true;
  };

  #services.polybar = {
  #  enable = true;
  #  package = pkgs.polybarFull;
  #  script = ''
  #    $HOME/.config/polybar/launch.sh --cuts &
  #    $HOME/.local/bin/polybar-reload &
  #  '';
  #};
}
