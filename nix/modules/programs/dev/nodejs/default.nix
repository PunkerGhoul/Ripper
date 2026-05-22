{ pkgs, lib, ... }:

{
  config.ripper.programs.packages = [
    pkgs.nodejs
  ];

  config.home.activation.install-node-dev-packages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail
    data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/ripper/node-dev"
    mkdir -p "$data_dir"

    # Install local dev packages if not already installed
    if [ ! -d "$data_dir/node_modules" ]; then
      ${pkgs.nodejs}/bin/npm install --prefix "$data_dir" dotenv zod lodash --no-audit --no-fund
      if [ "${VERBOSE:-}" != "" ]; then
        echo "Installed Node dev packages in $data_dir"
      fi
    fi
  '';
}
