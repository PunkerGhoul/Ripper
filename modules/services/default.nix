{ config, pkgs, ... }:

{
  imports = [
    (import ./polybar { inherit config pkgs; })
    (import ./picom { inherit pkgs; })
  ];
}
