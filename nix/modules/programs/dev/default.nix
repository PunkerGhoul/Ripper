{ config, pkgs, lib, ... }:

let
  clang = pkgs.runCommand "clang-dev-tools" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.clang}/bin/clang "$out/bin/clang"
    ln -s ${pkgs.clang}/bin/clang++ "$out/bin/clang++"
    ln -s ${pkgs.clang}/bin/clang-cpp "$out/bin/clang-cpp"
  '';
in

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
        clang
    ]
    ++ config.ripper.programs.dev.python.packages
    ++ config.ripper.programs.dev.nodejs.packages;
    description = "Packages provided by dev program modules (python/nodejs).";
  };
}
