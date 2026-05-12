{ config, pkgs, lib, ... }:

{
  imports = [
    (import ./python { inherit pkgs lib; })
    (import ./nodejs { inherit pkgs lib; })
  ];

  options.ripper.programs.dev.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [
        pkgs.go
        pkgs.cargo
        pkgs.gcc
        pkgs.clang
    ]
    ++ config.ripper.programs.dev.python.packages
    ++ config.ripper.programs.dev.nodejs.packages;
    description = "Packages provided by dev program modules (python/nodejs).";
  };
}
