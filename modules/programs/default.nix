{ config, sources, pkgs, unstable, env,... }:

{
  imports = [
    (import ./rofi { inherit config pkgs; })
    (import ./kitty { inherit sources pkgs unstable config; })
    (import ./zsh { inherit pkgs; })
    (import ./git { inherit pkgs env; })
    (import ./bat { inherit pkgs; })
    (import ./jq { inherit pkgs; })
    (import ./neovim { inherit pkgs; })
  ];
}
