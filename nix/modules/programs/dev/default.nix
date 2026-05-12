{ config, pkgs, lib, ... }:

{
  imports = [
    (import ./python { inherit pkgs; })
    (import ./nodejs { inherit pkgs lib; })
  ];

  options.ripper.programs.dev.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [
        pkgs.go
        pkgs.cargo
        pkgs.gcc
        pkgs.clang
    ];
    description = "Packages provided by dev program modules (python/nodejs).";
  };
}
