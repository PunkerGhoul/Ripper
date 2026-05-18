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

  config.ripper.programs.packages = [
    pkgs.curl
    pkgs.cron
    pkgs.wget
    pkgs.ripgrep
    pkgs.ffmpeg
    pkgs.netcat-gnu
    # Workaround for Sage doctest failures seen on some nixos-unstable revisions.
    # This may be unnecessary with a different nixpkgs revision/channel, such as nixpkgs-unstable.
    (pkgs.sage.overrideAttrs (_: {
      doInstallCheck = false;
    }))
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
