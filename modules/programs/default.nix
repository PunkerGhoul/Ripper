{ config, pkgs, lib, unstable, env, nixGLCommand, ... }:

{
  imports = [
    (import ./rofi { inherit config pkgs; })
    (import ./kitty { inherit config pkgs unstable nixGLCommand; })
    (import ./burpsuite { inherit pkgs lib; })
    (import ./logseq { inherit pkgs; })
    (import ./tmux { inherit pkgs; })
    (import ./zsh { inherit config pkgs lib; })
    (import ./git { inherit pkgs env; })
    (import ./bat { inherit pkgs; })
    (import ./jq { inherit pkgs; })
    (import ./neovim { inherit pkgs unstable; })
    (import ./librewolf { inherit pkgs; })
  ];
}
