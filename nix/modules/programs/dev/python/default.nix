{ pkgs, lib, ... }:

{
  options.ripper.programs.dev.python.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [
      (pkgs.python314.withPackages (ps: with ps; [ requests colorama rich tqdm ]))
      pkgs.python314Packages.pip
    ];
    description = "Python packages provided by the dev Python module.";
  };
}
