{ pkgs, ... }:

{
  oh-my-zsh = {
    enable = true;
    plugins = [
      "git"
      "command-not-found"
      "debian"
      "extract"
      "fzf"
      "nmap"
      "python"
      "tmux"
    ];
    extraConfig = ''
      zstyle ':omz:update' mode reminder
    '';
  };
}

