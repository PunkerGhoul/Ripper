{ config, pkgs, ... }:

{
  imports = [
    (import ./polkit-gnome { inherit pkgs; })
    (import ./gpg-agent { inherit pkgs; })
    (import ./polybar { inherit config pkgs; })
    (import ./dunst { inherit config pkgs; })
    (import ./picom { inherit pkgs; })
    (import ./audio { inherit pkgs; })
  ];
}
