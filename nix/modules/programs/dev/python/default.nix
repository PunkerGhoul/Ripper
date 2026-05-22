{ pkgs, ... }:

{
  config.ripper.programs.packages = [
    (pkgs.python314.withPackages (ps: with ps; [ requests colorama rich tqdm ]))
    pkgs.python314Packages.pip
  ];
}
