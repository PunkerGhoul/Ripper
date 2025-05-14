# Ripper

## Installation

1. Install nix with multi-user
2. Install Home-Manager

    ```bash
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --add https://github.com/nix-community/nixGL/archive/main.tar.gz nixgl
    nix-channel --update
    nix-shell '<home-manager>' -A install
    ```

3. Install Niv

    ```bash
    nix-env -iA nixpkgs.niv
    niv add NixOS/nixpkgs -n nixpkgs -b 24.11
    niv add NixOS/nixpkgs -n nixpkgs-unstable -b nixpkgs-unstable
    niv add nix-community/nixGL -n nixgl -b main
    ```

4. Clone this repository and apply the configuration:

    ```bash
    git clone https://github.com/PunkerGhoul/Ripper.git
    cd Ripper
    cp env.example.nix env.nix
    nano env.nix
    home-manager switch -f ./home.nix -b backup
    ```
