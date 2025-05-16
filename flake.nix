{
  description = "Ripper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl.url = "github:nix-community/nixGL";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixgl, ... }:
    let
      system = "ARCHITECTURE_VAR";
      pkgs = import nixpkgs {
        inherit system;
        #overlays = [ nixgl.overlay ];
      };

      username = "USERNAME_VAR";
    in {
      homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./home.nix
        ];

        extraSpecialArgs = {
          inherit inputs username;
        };
      };
    };
}

