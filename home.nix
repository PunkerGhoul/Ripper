{ config, pkgs, lib, ... }:

let
  unstable = import <nixpkgs-unstable> {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

  env = import ./env.nix;
  username = builtins.getEnv "USER";

  bashPath = "${pkgs.bash}/bin/bash";
  librewolfPath = "${pkgs.librewolf}/bin/librewolf";
in {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager Extra directories to prepend to PATH.
  # # These directories are added to the PATH variable in a double-quoted context, so expressions like $HOME are expanded by the shell.
  # # However, since expressions like ~ or * are escaped, they will end up in the PATH verbatim.
  home.sessionPath = [
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';

    ".hushlogin".text = "";

    # LibreWolf
    ## Personal profile
    ".local/bin/librewolf-personal" = {
      text = ''
      #!${bashPath}
        ${librewolfPath} -P "Personal" "$@"
      '';
      executable = true;
    };
    ## Pentesting profile
    ".local/bin/librewolf-pentesting" = {
      text = ''
      #!${bashPath}
        ${librewolfPath} -P "Pentesting" "$@"
      '';
      executable = true;
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/${username}/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  imports = [
    (import ./configuration { inherit pkgs; })
    (import ./modules { inherit config pkgs unstable lib env; })
  ];
}
