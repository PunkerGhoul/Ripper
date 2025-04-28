{ pkgs, ...}:

let
  ohMyZshConfig = import ./oh-my-zsh { inherit pkgs; };
  plugins = (import ./plugins { inherit pkgs; }).plugins;
in {
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    profileExtra = ''
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && [ "$(tty)" = "/dev/tty1" ]; then
        exec startx ${pkgs.i3}/bin/i3
      fi
    '';
    envExtra = ''
      export GPG_TTY=$(tty)
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
    inherit (ohMyZshConfig) oh-my-zsh;
    plugins = plugins;
  };
}
