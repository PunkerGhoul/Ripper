{ pkgs, lib, ... }:

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
    (import ./python { inherit pkgs; })
    (import ./nodejs { inherit pkgs lib; })
  ];

  config.ripper.programs.packages = [
    pkgs.go
    pkgs.cargo
    pkgs.gcc
    clang
    pkgs.pkg-config
  ];
}
