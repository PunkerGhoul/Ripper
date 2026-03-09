{ config, pkgs, lib, ... }:

{
  home.activation.install-xorg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking Xorg installation..."
    
    if ! command -v X >/dev/null || ! command -v xinit >/dev/null; then
      echo "Installing Xorg core packages..."
      
      if command -v apt >/dev/null; then
        echo "Detected Debian/Ubuntu system, using apt..."
        export PATH=${pkgs.apt}/bin:$PATH
        sudo apt update -y
        sudo apt install -y \
          xorg xorg-dev x11-apps xinit
        echo "Xorg installation completed using apt."
      elif command -v pacman >/dev/null; then
        echo "Detected Arch Linux system, using pacman..."
        export PATH=${pkgs.pacman}/bin:$PATH
        sudo pacman -Syu --needed --noconfirm \
          xorg-server xorg-xinit xorg-xauth xorg-apps
        echo "Xorg installation completed using pacman."
      else
        echo "Warning: No supported package manager found (apt or pacman)."
        echo "Please install Xorg core packages manually:"
        echo "  - xorg-server, xorg-xinit, xorg-xauth, xorg-apps"
        echo "Xorg installation skipped: unable to install packages automatically."
      fi
    else
      echo "Xorg is already installed."
    fi
  '';

  home.activation.install-vmware-tools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking VMware environment..."
    
    # Detect VMware using lspci
    is_vmware=false
    if command -v lspci >/dev/null 2>&1; then
      if lspci 2>/dev/null | grep -qi vmware; then
        is_vmware=true
      fi
    fi
    
    # Fallback to dmesg if lspci not available
    if [ "$is_vmware" = "false" ] && command -v dmesg >/dev/null 2>&1; then
      if sudo dmesg 2>/dev/null | grep -qi vmware; then
        is_vmware=true
      fi
    fi
    
    if [ "$is_vmware" = "false" ]; then
      echo "Not running in VMware."
      exit 0
    fi
    
    echo "VMware environment detected."
    
    # Step 1: Install open-vm-tools if not present
    if ! command -v vmware-toolbox-cmd >/dev/null 2>&1; then
      echo "Installing open-vm-tools..."
      
      if command -v apt >/dev/null 2>&1; then
        sudo apt update -y
        sudo apt install -y open-vm-tools open-vm-tools-desktop fuse3
        echo "open-vm-tools installed via apt."
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm open-vm-tools gtkmm3 fuse3
        echo "open-vm-tools installed via pacman."
      else
        echo "WARNING: Cannot install open-vm-tools automatically."
        echo "Please install manually and run: home-manager switch"
        exit 0
      fi
    else
      echo "open-vm-tools already installed."
      
      # Ensure fuse and desktop components are installed
      if command -v apt >/dev/null 2>&1; then
        if ! dpkg -l | grep -q "^ii.*fuse3"; then
          sudo apt install -y fuse3
        fi
        if ! dpkg -l | grep -q "^ii.*open-vm-tools-desktop"; then
          sudo apt install -y open-vm-tools-desktop
        fi
      elif command -v pacman >/dev/null 2>&1; then
        if ! pacman -Q fuse3 >/dev/null 2>&1; then
          sudo pacman -S --needed --noconfirm fuse3
        fi
        if ! pacman -Q gtkmm3 >/dev/null 2>&1; then
          sudo pacman -S --needed --noconfirm gtkmm3
        fi
      fi
    fi
    
    # Step 2: Enable and start vmtoolsd and vmware-vmblock-fuse services
    if systemctl is-active vmtoolsd >/dev/null 2>&1; then
      echo "vmtoolsd service is already running."
    else
      echo "Enabling and starting vmtoolsd service..."
      if sudo systemctl enable vmtoolsd 2>/dev/null && sudo systemctl start vmtoolsd 2>/dev/null; then
        echo "vmtoolsd service started successfully."
      else
        echo "WARNING: Failed to start vmtoolsd service."
        echo "Try manually: sudo systemctl enable --now vmtoolsd"
      fi
    fi
    
    # Enable vmware-vmblock-fuse service
    if systemctl is-enabled vmware-vmblock-fuse.service >/dev/null 2>&1; then
      echo "vmware-vmblock-fuse.service already enabled."
    else
      echo "Enabling vmware-vmblock-fuse.service..."
      if sudo systemctl enable vmware-vmblock-fuse.service 2>/dev/null; then
        echo "vmware-vmblock-fuse.service enabled."
      fi
    fi
    
    if systemctl is-active vmware-vmblock-fuse.service >/dev/null 2>&1; then
      echo "vmware-vmblock-fuse.service is already running."
    else
      echo "Starting vmware-vmblock-fuse.service..."
      sudo systemctl start vmware-vmblock-fuse.service 2>/dev/null || echo "Note: vmware-vmblock-fuse.service will start on next boot."
    fi
  '';

  systemd.user.services.vmware-user = {
    Unit = {
      Description = "VMware User Agent (clipboard, drag-and-drop, auto-resize)";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionVirtualization = "vmware";
    };
    Service = {
      Type = "simple";
      ExecStart = "/usr/bin/vmware-user";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=%h/.Xauthority"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  home.file.".xinitrc".text = builtins.replaceStrings
    [ "{{homeDirectory}}" ]
    [ config.home.homeDirectory ]
    (builtins.readFile ./xinitrc);

  # Listens for X11 RandR events emitted by vmwgfx when VMware resizes or goes fullscreen,
  # then applies the new preferred mode immediately — event-driven, no polling, no udev rules needed
  systemd.user.services.vmware-auto-resize = {
    Unit = {
      Description = "Apply VMware display resize via X11 RandR events";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionVirtualization = "vmware";
    };
    Service = {
      Type = "simple";
      ExecStart = toString (pkgs.writeShellScript "vmware-auto-resize" ''
        ${pkgs.coreutils}/bin/stdbuf -oL \
          ${pkgs.xev}/bin/xev -root -event randr |
        while IFS= read -r line; do
          case "$line" in
            *event,*)
              output=$(${pkgs.xrandr}/bin/xrandr | ${pkgs.gawk}/bin/awk '/ connected/{print $1; exit}')
              [ -n "$output" ] && ${pkgs.xrandr}/bin/xrandr --output "$output" --auto
              ;;
          esac
        done
      '');
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=%h/.Xauthority"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = with pkgs; [
    pciutils    # lspci for VMware detection
    xrandr      # available in PATH for manual use
  ];

  xsession = {
    enable = true;
  };

  imports = [
    (import ./i3 { inherit config pkgs lib; })
  ];
}
