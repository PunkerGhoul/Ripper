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
    # Sage is intentionally sourced from nixosPkgs; switch to pkgs.sage to use the base nixpkgs input.
    # The install check override works around Sage doctest failures seen on some nixos-unstable revisions.
    (nixosPkgs.sage.overrideAttrs (_: {
      doInstallCheck = false;
    }))
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
