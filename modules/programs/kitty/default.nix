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
      exec ${kittyPackage}/bin/kitty --single-instance "$@"
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
      enable_audio_bell = "no";
      enabled_layouts = "grid";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      background_opacity = 0.7;
      input_delay = 0;
      repaint_delay = 2;
      resize_debounce_time = "0 0";
      scrollback_lines = 1000;
      sync_to_monitor = "no";
      shell = "${pkgs.zsh}/bin/zsh";
      term = "xterm-256color";
    };
  };
}
