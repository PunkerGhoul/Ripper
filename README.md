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
    home-manager switch -f ./home.nix -b backup
    ```

## Description

This project allows to easily manage and switch between different configurations for various environments. It uses Nix and Home-Manager to create reproducible and isolated environments for development, gaming, and other use cases. The `env.nix` file can be customized to include the necessary packages and configurations for each environment, making it easy to switch between them with a single command.

> Note: This project is still in development and may not be fully functional. Use at your own risk.

> [!WARNING]  
> Is oriented towards VMware, therefore some configurations may not work properly on physical hardware. Use with caution and test thoroughly before applying to a production environment.
