{ pkgs, ... }:

{
  # Enable NUR (Nix User Repository) for additional packages
  nixpkgs.config = {
    packageOverrides = pkgs: {
      nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
        inherit pkgs;
      };
    };
    # Allow unfree packages (needed for some browser extensions)
    allowUnfree = true;
  };

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      frequency = "weekly";
      options = "--delete-older-than 15d";
    };
  };
}
