{ pkgs, ... }:

{
  # NUR is provided by the flake overlay. Keep this module free of impure fetches.
  nixpkgs.config = {
    allowUnfree = true;
  };

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 15d";
    };
  };
}
