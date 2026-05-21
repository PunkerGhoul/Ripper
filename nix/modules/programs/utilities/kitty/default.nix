{ config, pkgs, unstable, nixGLCommand, ... }:

let
  nixGL = import ../../../nixgl { inherit pkgs nixGLCommand; };
  kittyPackage = nixGL unstable.kitty;
in
{
  xdg.enable = true;
  home.file.".config/kitty/color.ini".source = ./color.ini;
  home.file.".local/bin/ripper-kitty" = {
    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/ripper/kitty"
      ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
      log="$state_dir/kitty.log"

      # Keep long-lived Kitty processes from retaining excessive glibc arenas.
      export MALLOC_ARENA_MAX=2
      export MALLOC_TRIM_THRESHOLD_=131072

      {
        printf '[%s] starting kitty pid=%s args=%s\n' "$(${pkgs.coreutils}/bin/date -Is)" "$$" "$*"
        exec ${kittyPackage}/bin/kitty "$@"
      } >>"$log" 2>&1
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
      "kitty_mod+enter" = "new_window_with_cwd";
      "kitty_mod+space" = "new_window";
    };
    shellIntegration = {
      mode = null;
    };
    settings = {
      include = "color.ini";
      kitty_mod = "ctrl+shift";
      disable_ligatures = "never";
      url_color = "#b96507";
      url_style = "curly";
      open_url_with = "librewolf";
      detect_urls = "yes";
      enable_audio_bell = "no";
      enabled_layouts = "grid";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      background_opacity = 0.6;
      input_delay = 3;
      repaint_delay = 10;
      resize_debounce_time = "0.1 0.5";
      scrollback_lines = 1000;
      close_on_child_death = "no";
      sync_to_monitor = "no";
      shell = "${pkgs.zsh}/bin/zsh";
      term = "xterm-256color";
    };
  };
}
