{ config, pkgs, lib, unstable, env, nixGLCommand, ... }:

{
  imports = [
    (import ./bat { inherit pkgs; })
    (import ./git { inherit pkgs env; })
    (import ./jq { inherit pkgs; })
    (import ./kitty { inherit config pkgs unstable nixGLCommand; })
    (import ./logseq { inherit pkgs; })
    (import ./neovim { inherit pkgs unstable; })
    (import ./rofi { inherit config pkgs; })
    (import ./tmux { inherit pkgs; })
    (import ./zsh { inherit config pkgs lib; })
  ];
}
