{ pkgs, ... }:

{
  services.polkit-gnome = {
    enable = false;
    package = pkgs.polkit_gnome;
  };
}
