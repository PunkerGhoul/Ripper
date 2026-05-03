{ config, pkgs, lib, unstable, env, nixGLCommand, ... }:

{
  imports = [
    (import ./bat { inherit pkgs; })
    (import ./git { inherit pkgs env; })
    (import ./jq { inherit pkgs; })
    (import ./kitty { inherit config pkgs unstable nixGLCommand; })
    (import ./neovim { inherit pkgs unstable; })
    (import ./rofi { inherit config pkgs; })
    (import ./tmux { inherit pkgs; })
    (import ./zsh { inherit config pkgs lib; })
  ];

  options.ripper.programs.utilities.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [
        pkgs.sage
        pkgs.go
        pkgs.logseq
        pkgs.openvpn
    ];
    description = "Packages provided by utility program modules.";
  };
}
