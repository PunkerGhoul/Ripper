{ config, pkgs, lib, ... }:

{
  options.ripper.programs.dev.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [ pkgs.go ];
    description = "Packages provided by dev program modules (python/nodejs).";
  };

  # Expose the configured list (will be combined by programs/default.nix)
  config = {
    ripper.programs.dev.packages = config.ripper.programs.dev.packages or [];
  };
}
