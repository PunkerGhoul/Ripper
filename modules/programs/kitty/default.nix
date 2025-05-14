{ sources, pkgs, unstable, config, ...}:

let
  nixGL = import ../../nixgl  { inherit config sources pkgs; };
in {
  home.file.".config/kitty/color.ini".source = ./color.ini;

  programs.kitty = {
    enable = true;
    package = (nixGL unstable.kitty);
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
      shell = "zsh";
    };
  };
}
