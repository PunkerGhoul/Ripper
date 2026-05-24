{ config, pkgs, lib, unstable, nixosPkgs, env, nixGLCommand, ... }:

{
  imports = [
    (import ./bat { inherit pkgs; })
    (import ./codex { inherit nixosPkgs; })
    (import ./git { inherit pkgs env; })
    (import ./jq { inherit pkgs; })
    (import ./fzf { inherit pkgs; })
    (import ./kitty { inherit config pkgs unstable nixGLCommand; })
    (import ./neovim { inherit pkgs unstable; })
    (import ./rofi { inherit config pkgs; })
    (import ./sage { inherit lib nixosPkgs; })
    (import ./tmux { inherit pkgs; })
    (import ./zsh { inherit config pkgs lib; })
  ];

  config.ripper.programs.packages = [
    pkgs.curl
    pkgs.cron
    pkgs.wget
    pkgs.ripgrep
    pkgs.ffmpeg
    pkgs.uv
    pkgs.netcat-gnu
    pkgs.socat
    pkgs.inetutils
    pkgs.strace
    pkgs.logseq
    pkgs.openvpn
    pkgs.xxd
    pkgs.xcd
    pkgs.xdg-utils
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
