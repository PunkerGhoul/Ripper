{ pkgs, ...}:

{
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    profileExtra = ''
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && [ "$(tty)" = "/dev/tty1" ]; then
        exec startx /usr/bin/i3
      fi
    '';
    envExtra = ''
      export GOPATH=$HOME/.go
      export PATH="$PATH:$GOPATH/bin"
      export PATH="$PATH:$HOME/Documents/Tools"
    '';
    shellAliases = {
      ipfuscate = ''
        function _ipfuscate() { python3 /opt/IPFuscator/ipfuscator.py "$1" | awk -F "\t" "/IP Address:/,0 {if (\$2 && \$2 !~ /:$| \$/) {gsub(\" \", \"\t\", \$2); print \$2}}"; }; _ipfuscate;
      '';
      zap = "/usr/local/bin/zap.sh";
    };
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
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
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = ./p10k-config;
        file = "p10k.zsh";
      }
    ];
  };
}
