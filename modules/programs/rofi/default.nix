{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    configPath = "${config.home.homeDirectory}/.config/rofi/config.rasi";
    theme = "${pkgs.rofi}/share/rofi/themes/lb.rasi";
  };
}
