# Ripper

## Installation

1. Install nix with multi-user
2. Install Home-Manager

    ```bash
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs-unstable
    nix-channel --add https://github.com/nix-community/nixGL/archive/main.tar.gz nixgl
    nix-channel --update
    nix-shell '<home-manager>' -A install
    ```

3. Clone this repository and apply the configuration:

    ```bash
    git clone https://github.com/PunkerGhoul/Ripper.git
    cd Ripper
    cp env.example.nix env.nix
    nano env.nix
    ./setup.sh && home-manager switch --impure --flake ~/.config/Ripper#$(/bin/id -gn) -b backup --show-trace
    ```
