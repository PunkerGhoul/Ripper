{ pkgs, ... }:

{
  imports = [
    (import ./picom { inherit pkgs; })
  ];
}
