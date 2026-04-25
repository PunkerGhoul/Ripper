{ config, pkgs, logoutScript, ... }:

{
  imports = [
    (import ./polkit-gnome { inherit pkgs; })
    (import ./gpg-agent { inherit pkgs; })
    (import ./polybar { inherit config pkgs logoutScript; })
    (import ./dunst { inherit config pkgs; })
    (import ./picom { inherit pkgs; })
  ];
}
