{ config, pkgs, lib, ...}:

let
  ohMyZshConfig = import ./oh-my-zsh { inherit pkgs; };
  pluginsList = import ./plugins { inherit pkgs; };
in {
  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    profileExtra = ''
      # Source home-manager session variables early
      if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
    envExtra = ''
      export GPG_TTY="$TTY"
      export GOPATH=$HOME/.go
      export PATH="$PATH:$GOPATH/bin"
      export PATH="$PATH:$HOME/Documents/Tools"
      export PATH="$PATH:$HOME/.local/bin"
      export FZF_BASE="${pkgs.fzf}/share/fzf"

      # Historial robusto: append incremental + lock para evitar corrupcion
      export HISTFILE="$ZDOTDIR/.zsh_history"
      export HISTSIZE=100000
      export SAVEHIST=100000
    '';
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Powerlevel10k instant prompt must stay before oh-my-zsh/plugins.
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        _ripper_zsh_cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
        export ZSH_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
        [[ -d "$_ripper_zsh_cache_dir" && -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$_ripper_zsh_cache_dir" "$ZSH_CACHE_DIR"

        export ZSH_DISABLE_COMPFIX=true
        export ZSH_COMPDUMP="$_ripper_zsh_cache_dir/.zcompdump-''${HOST:-unknown}-''${ZSH_VERSION}"
        zstyle ':completion:*' use-cache on
        zstyle ':completion:*' cache-path "$_ripper_zsh_cache_dir/zcompcache"

        # Evita reescrituras completas y habilita lock del historial entre shells concurrentes.
        setopt APPEND_HISTORY INC_APPEND_HISTORY HIST_FCNTL_LOCK HIST_SAVE_BY_COPY
        setopt HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_FIND_NO_DUPS
        unsetopt SHARE_HISTORY
      '')
      (lib.mkAfter ''
        # Keep the full plugin stack, but compile startup files after the prompt is usable.
        () {
          emulate -L zsh
          setopt no_bg_nice
          () {
            emulate -L zsh
            local zsh_file
            for zsh_file in \
              "$ZDOTDIR/.zshrc" \
              "$ZDOTDIR/.zshenv" \
              "$ZDOTDIR/.zprofile" \
              "$ZSH_COMPDUMP"; do
              [[ -r "$zsh_file" ]] || continue
              [[ ! -r "$zsh_file.zwc" || "$zsh_file" -nt "$zsh_file.zwc" ]] || continue
              zcompile -R "$zsh_file" >/dev/null 2>&1 || true
            done
          } >/dev/null 2>&1 &!
        }
      '')
    ];
    shellAliases = {
      ipfuscate = ''
        function _ipfuscate() { python3 /opt/IPFuscator/ipfuscator.py "$1" | awk -F "\t" "/IP Address:/,0 {if (\$2 && \$2 !~ /:$| \$/) {gsub(\" \", \"\t\", \$2); print \$2}}"; }; _ipfuscate;
      '';
      zap = "/usr/local/bin/zap.sh";
      open = "${pkgs.xdg-utils}/bin/xdg-open";
    };
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    inherit (ohMyZshConfig) oh-my-zsh;
    inherit (pluginsList) plugins;
  };

  home.activation.compile-zsh-startup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    zsh_bin="${pkgs.zsh}/bin/zsh"
    zsh_dir="${config.home.homeDirectory}/.config/zsh"
    cache_dir="${config.xdg.cacheHome}/zsh"

    ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"
    for zsh_file in "$zsh_dir/.zshrc" "$zsh_dir/.zshenv" "$zsh_dir/.zprofile"; do
      if [ -r "$zsh_file" ]; then
        "$zsh_bin" -fc 'zcompile -R "$1"' ripper-compile-zsh "$zsh_file" >/dev/null 2>&1 || true
      fi
    done
  '';
}
