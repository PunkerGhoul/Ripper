{ config, pkgs, lib, unstable, env, nixGLCommand, ... }:

{
  imports = [
    (import ./utilities { inherit config pkgs lib unstable env nixGLCommand; })
    (import ./pentesting { inherit pkgs lib; })
  ];

  options.ripper.programs.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [];
    description = "Combined package list from the program modules.";
  };

  config.ripper.programs.packages =
    config.ripper.programs.utilities.packages
    ++ config.ripper.programs.pentesting.packages;
}
