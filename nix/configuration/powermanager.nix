{ config, pkgs, lib, ... }:

let
  # Importa el usuario desde local/install.nix
  install = import ../../local/install.nix;
  user = install.user;
  sudoersFile = "/etc/sudoers.d/90-user-powermanager";
  group = "powermanager";
  allowedCommands = [
    "/run/current-system/sw/bin/poweroff"
    "/run/current-system/sw/bin/reboot"
    "/run/current-system/sw/bin/systemctl poweroff"
    "/run/current-system/sw/bin/systemctl reboot"
    "/run/current-system/sw/bin/systemctl suspend"
    "/run/current-system/sw/bin/systemctl hibernate"
    "/run/current-system/sw/bin/systemctl hybrid-sleep"
  ];
  sudoersLine =
    group +
    " ALL=(root) NOPASSWD: " +
    (lib.concatStringsSep ", " allowedCommands) + "\n";
in
{
  users.groups.${group} = {};
  users.users.${user}.extraGroups = [ group ];

  environment.etc."sudoers.d/90-user-powermanager".text = sudoersLine;
  environment.etc."sudoers.d/90-user-powermanager".mode = "0440";
}
