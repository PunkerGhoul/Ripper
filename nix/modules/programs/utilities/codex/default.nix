{ nixosPkgs, ... }:

{
  ripper.programs.packages = [ nixosPkgs.codex ];
}
