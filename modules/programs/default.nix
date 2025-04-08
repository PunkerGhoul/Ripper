{ pkgs, env, ... }:

{
  imports = [
    (import ./zsh { inherit pkgs; })
    (import ./git { inherit pkgs env; })
  ];
}
