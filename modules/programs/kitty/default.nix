{ config, pkgs, unstable, nixGLCommand, ...}:

let
  nixGL = import ../../nixgl  { inherit pkgs nixGLCommand; };
  kittyPackage = nixGL unstable.kitty;
in {
  xdg.enable = true;
  home.file.".config/kitty/color.ini".source = ./color.ini;
  home.file.".local/bin/ripper-kitty" = {
    text = ''
      #!${pkgs.runtimeShell}
      set -u

      runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
      mkdir -p "$runtime_dir"
      chmod 700 "$runtime_dir" 2>/dev/null || true
      socket="$runtime_dir/ripper-kitty.sock"
      to="unix:$socket"

      launch_remote() {
        [ -S "$socket" ] || return 1
        ${kittyPackage}/bin/kitty @ --to "$to" ls >/dev/null 2>&1 || return 1

        if [ "$#" -eq 0 ]; then
          ${kittyPackage}/bin/kitty @ --to "$to" launch --type=os-window --cwd "$PWD"
        else
          ${kittyPackage}/bin/kitty @ --to "$to" launch --type=os-window --cwd "$PWD" -- "$@"
        fi
      }

      if launch_remote "$@"; then
        exit 0
      fi

      lock="$runtime_dir/ripper-kitty.lock"
      exec 9>"$lock"
      ${pkgs.util-linux}/bin/flock 9

      if launch_remote "$@"; then
        exit 0
      fi

      rm -f "$socket"
      ${kittyPackage}/bin/kitty --listen-on "$to" "$@" &
      kitty_pid="$!"

      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 \
        21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40; do
        if [ -S "$socket" ] && ${kittyPackage}/bin/kitty @ --to "$to" ls >/dev/null 2>&1; then
          ${pkgs.util-linux}/bin/flock -u 9
          wait "$kitty_pid"
          exit "$?"
        fi

        if ! kill -0 "$kitty_pid" 2>/dev/null; then
          ${pkgs.util-linux}/bin/flock -u 9
          wait "$kitty_pid"
          exit "$?"
        fi

        ${pkgs.coreutils}/bin/sleep 0.025
      done

      ${pkgs.util-linux}/bin/flock -u 9
      wait "$kitty_pid"
    '';
    executable = true;
  };

  xdg.desktopEntries.kitty = {
    name = "Kitty";
    genericName = "Terminal emulator";
    comment = "Fast, feature-rich, GPU based terminal";
    exec = "${config.home.homeDirectory}/.local/bin/ripper-kitty";
    icon = "kitty";
    terminal = false;
    categories = [ "System" "TerminalEmulator" ];
  };

  programs.kitty = {
    enable = true;
    package = kittyPackage;
    font = {
      package = pkgs.meslo-lgs-nf;
      name = "MesloLGS NF";
    };
    keybindings = {
      "kitty_mod+y" = "new_tab_with_cwd";
    };
    shellIntegration = {
      mode = null;
    };
    settings = {
      include = "color.ini";
      disable_ligatures = "never";
      url_color = "#b96507";
      url_style = "curly";
      open_url_with = "librewolf";
      detect_urls = "yes";
      allow_remote_control = "socket-only";
      enable_audio_bell = "no";
      enabled_layouts = "grid";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      background_opacity = 1.0;
      input_delay = 0;
      repaint_delay = 2;
      sync_to_monitor = "no";
      shell = "${pkgs.zsh}/bin/zsh";
      term = "xterm-256color";
    };
  };
}
