{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;
    configFile = "${config.home.homeDirectory}/.config/dunst/dunstrc";
    iconTheme = {
      package = pkgs.dracula-icon-theme;
      name = "Dracula";
    };
  };
}
