{ pkgs, ... }:

{
  ripper.programs.utilities.packages = [ pkgs.go ];
}
