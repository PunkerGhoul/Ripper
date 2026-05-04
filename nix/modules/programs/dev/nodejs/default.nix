{ pkgs, ... }:

{
  # Node.js dev packages
  config.ripper.programs.dev.packages = [
    pkgs.nodePackages.dotenv
    pkgs.nodePackages.zod
    pkgs.nodePackages.lodash
  ];
}
