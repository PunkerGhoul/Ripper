{ config, pkgs, lib, ...}:

let
  ohMyZshConfig = import ./oh-my-zsh { inherit pkgs; };
  pluginsList = import ./plugins { inherit pkgs; };
in {
  home.activation.setZshAsDefaultShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking default shell..."
    
    # Get current shell - try multiple methods
    CURRENT_SHELL=""
    if command -v getent >/dev/null 2>&1; then
      CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
    fi
    
    if [ -z "$CURRENT_SHELL" ] && [ -f /etc/passwd ]; then
      CURRENT_SHELL=$(grep "^$USER:" /etc/passwd | cut -d: -f7)
    fi
    
    if [ -z "$CURRENT_SHELL" ]; then
      echo "Warning: Could not determine current shell, skipping shell change."
      exit 0
    fi
    
    echo "Current shell: $CURRENT_SHELL"
    
    # Use Nix-provided zsh path
    ZSH_PATH="${pkgs.zsh}/bin/zsh"
    echo "Using Nix zsh at: $ZSH_PATH"
    
    if [ ! -f "$ZSH_PATH" ]; then
      echo "Warning: Nix zsh not found at $ZSH_PATH, skipping shell change."
      exit 0
    fi
    
    # Check if already using zsh
    if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
      echo "Default shell is already zsh."
      exit 0
    fi
    
    echo "Attempting to change default shell to zsh..."
    
    # Check if zsh is in /etc/shells
    if [ -f /etc/shells ] && ! grep -q "^$ZSH_PATH$" /etc/shells 2>/dev/null; then
      echo "Adding $ZSH_PATH to /etc/shells..."
      if ! echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null 2>&1; then
        echo "Warning: Failed to add zsh to /etc/shells. You may need to run manually:"
        echo "  echo '$ZSH_PATH' | sudo tee -a /etc/shells"
      fi
    fi
    
    # Change shell
    echo "Changing shell with chsh..."
    if sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
      echo "Default shell changed to zsh successfully."
      echo "  Please log out and log back in for changes to take effect."
    else
      echo "Warning: Failed to change shell automatically. Run manually:"
      echo "  sudo chsh -s $ZSH_PATH $USER"
    fi
  '';

  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    profileExtra = ''
      # Source home-manager session variables early
      if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
    loginExtra = ''
      # Auto-start X at login on tty1 (runs after full zsh initialization)
      if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        exec startx
      fi
    '';
    envExtra = ''
      export GPG_TTY=$(tty)
      export GOPATH=$HOME/.go
      export PATH="$PATH:$GOPATH/bin"
      export PATH="$PATH:$HOME/Documents/Tools"
      export PATH="$PATH:$HOME/.local/bin"
      export FZF_BASE="${pkgs.fzf}/share/fzf"
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
    inherit (pluginsList) plugins;
  };
}
