{ config, pkgs, lib, unstable, env, nixGLCommand, ... }:

{
  imports = [
    (import ./bat { inherit pkgs; })
    (import ./codex { inherit pkgs; })
    (import ./git { inherit pkgs env; })
    (import ./jq { inherit pkgs; })
    (import ./fzf { inherit pkgs; })
    (import ./kitty { inherit config pkgs unstable nixGLCommand; })
    (import ./neovim { inherit pkgs unstable; })
    (import ./rofi { inherit config pkgs; })
    (import ./tmux { inherit pkgs; })
    (import ./zsh { inherit config pkgs lib; })
  ];

  options.ripper.programs.utilities.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = [];
    description = "Packages provided by utility program modules.";
  };

  config.ripper.programs.utilities.packages = [
    pkgs.curl
    pkgs.cron
    pkgs.wget
    pkgs.ripgrep
    pkgs.ffmpeg
    pkgs.netcat-gnu
    pkgs.sage
    pkgs.logseq
    pkgs.openvpn
    pkgs.xxd
    pkgs.xcd
    pkgs.xclip
    pkgs.tree
    pkgs.unzip
    pkgs.rsync
    pkgs.zip
    pkgs.gnutar
    pkgs.gzip
    pkgs.basez
  ];
}
