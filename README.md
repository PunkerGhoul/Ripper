# Ripper

## Installation

1. Install nix with multi-user
2. Install Home-Manager

    ```bash
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
    nix-shell '<home-manager>' -A install
    ```

3. Clone this repository and apply the configuration:

    ```bash
    git clone https://github.com/PunkerGhoul/Ripper.git
    cd Ripper
    home-manager switch -f ./home.nix
    ```
