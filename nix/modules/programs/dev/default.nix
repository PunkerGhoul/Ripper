{ pkgs, lib, ... }:

{
  imports = [
    (import ./python { inherit pkgs; })
    (import ./nodejs { inherit pkgs config; })
  ];

  options.ripper.programs.dev.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [ pkgs.go ];
    description = "Packages provided by dev program modules (python/nodejs).";
  };
}
