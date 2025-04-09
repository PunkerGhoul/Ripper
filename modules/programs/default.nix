{ config, pkgs, env, ... }:

{
  imports = [
    (import ./rofi { inherit config pkgs; })
    (import ./zsh { inherit pkgs; })
    (import ./git { inherit pkgs env; })
  ];
}
