{ config, pkgs, lib, nixGLCommand, logoutScript, ... }:

{
  imports = [
    (import ./lxqt-policykit { inherit pkgs; })
    (import ./gpg-agent { inherit pkgs; })
    (import ./keyboard { inherit config pkgs lib; })
    (import ./polybar { inherit config pkgs lib logoutScript; })
    (import ./dunst { inherit config pkgs; })
    (import ./picom { inherit config pkgs lib nixGLCommand; })
  ];
}
