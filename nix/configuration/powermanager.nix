{ config, pkgs, lib, ... }:

let
  install = import ../../local/install.nix;
  user = install.user;
  group = "powermanager";
in
{
  users.users.${user}.extraGroups = [ group ];
}
