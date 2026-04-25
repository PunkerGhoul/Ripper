{ pkgs, ... }:

{
  imports = [
    (import ./nix { inherit pkgs; })
  ];
}
