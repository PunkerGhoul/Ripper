{ config, pkgs, lib, ... }:

let
  install = import ../../local/install.nix;
  user = install.username or install.user;
in
{
  home.activation.powermanager = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "powermanager is managed by the installer for ${user}"
  '';
}
