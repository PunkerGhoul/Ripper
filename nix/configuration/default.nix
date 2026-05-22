{ pkgs, ... }:

{
  imports = [
    (import ./nix { inherit pkgs; })
    ./powermanager.nix
    ./resolved
  ];
}
