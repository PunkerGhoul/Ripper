{ config, pkgs, ... }:

{
  imports = [
    (import ./polkit-gnome { inherit pkgs; })
    (import ./polybar { inherit config pkgs; })
    (import ./picom { inherit pkgs; })
  ];
}
