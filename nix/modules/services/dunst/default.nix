{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.libnotify
  ];

  services.dunst = {
    enable = true;
    configFile = ./dunstrc;
    iconTheme = {
      package = pkgs.dracula-icon-theme;
      name = "Dracula";
    };
  };
}
