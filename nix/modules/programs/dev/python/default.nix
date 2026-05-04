{ pkgs, ... }:

{
  # Provide a Python runtime with common dev dependencies preinstalled
  config.ripper.programs.dev.packages = [
    (pkgs.python314.withPackages (ps: with ps; [ requests colorama rich tqdm ]))
    pkgs.python314Packages.pip
  ];
}
