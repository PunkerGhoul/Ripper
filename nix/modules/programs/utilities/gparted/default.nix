{ pkgs, ... }:

let
  gparted = pkgs.writeShellApplication {
    name = "gparted";
    text = ''
      exec /usr/bin/sudo -H ${pkgs.gparted}/bin/gparted "$@"
    '';
  };
in
{
  ripper.programs.packages = [ gparted ];
}
