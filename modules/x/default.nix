{ config, pkgs, lib, ... }:

{
  home.activation.install-xorg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking Xorg installation..."
    
    if ! command -v X >/dev/null || ! command -v xinit >/dev/null; then
      echo "Installing Xorg core packages..."
      
      if command -v apt >/dev/null; then
        echo "Detected Debian/Ubuntu system, using apt..."
        export PATH=${pkgs.apt}/bin:$PATH
        sudo apt update -y
        sudo apt install -y \
          xorg xorg-dev x11-apps xinit
        echo "Xorg installation completed using apt."
      elif command -v pacman >/dev/null; then
        echo "Detected Arch Linux system, using pacman..."
        export PATH=${pkgs.pacman}/bin:$PATH
        sudo pacman -Syu --needed --noconfirm \
          xorg-server xorg-xinit xorg-xauth xorg-apps
        echo "Xorg installation completed using pacman."
      else
        echo "Warning: No supported package manager found (apt or pacman)."
        echo "Please install Xorg core packages manually:"
        echo "  - xorg-server, xorg-xinit, xorg-xauth, xorg-apps"
        echo "Xorg installation skipped: unable to install packages automatically."
      fi
    else
      echo "Xorg is already installed."
    fi
  '';

  home.file.".xinitrc".text = builtins.replaceStrings
    [ "{{homeDirectory}}" ]
    [ config.home.homeDirectory ]
    (builtins.readFile ./xinitrc);

  xsession = {
    enable = true;
  };

  imports = [
    (import ./i3 { inherit config pkgs lib; })
  ];
}
