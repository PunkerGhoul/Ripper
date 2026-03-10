{ config, pkgs, lib, ... }:

{
  home.activation.install-xorg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! [ -x /usr/bin/X ] || ! [ -x /usr/bin/xinit ]; then
      if [ -x /usr/bin/apt ]; then
        /usr/bin/sudo /usr/bin/apt update -y
        /usr/bin/sudo /usr/bin/apt install -y xorg xorg-dev x11-apps xinit
      elif [ -x /usr/bin/pacman ]; then
        /usr/bin/sudo /usr/bin/pacman -Syu --needed --noconfirm xorg-server xorg-xinit xorg-xauth xorg-apps
      else
        echo "Warning: no supported package manager found. Install xorg-server, xorg-xinit, xorg-xauth, xorg-apps manually."
      fi
    fi
  '';

  home.activation.install-vmware-tools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Checking VMware environment..."
    
    # Detect VMware using pkgs from the nix store
    is_vmware=false
    if ${pkgs.gnugrep}/bin/grep -qi vmware /sys/class/dmi/id/sys_vendor 2>/dev/null \
       || ${pkgs.gnugrep}/bin/grep -qi vmware /sys/class/dmi/id/product_name 2>/dev/null; then
      is_vmware=true
    fi
    
    if [ "$is_vmware" = "false" ]; then
      if ${pkgs.systemd}/bin/systemd-detect-virt 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi vmware; then
        is_vmware=true
      fi
    fi
    
    if [ "$is_vmware" = "false" ]; then
      if ${pkgs.pciutils}/bin/lspci 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi vmware; then
        is_vmware=true
      fi
    fi
    
    if [ "$is_vmware" = "false" ]; then
      echo "Not running in VMware."
      exit 0
    fi
    
    echo "VMware environment detected."

    if [ -x /usr/bin/apt ]; then
      /usr/bin/sudo /usr/bin/apt update -y
      /usr/bin/sudo /usr/bin/apt install -y open-vm-tools open-vm-tools-desktop fuse3
    elif [ -x /usr/bin/pacman ]; then
      /usr/bin/sudo /usr/bin/pacman -Syu --needed --noconfirm open-vm-tools gtkmm3 fuse3
    else
      echo "WARNING: No supported package manager found. Install open-vm-tools, open-vm-tools-desktop and fuse3 manually."
      exit 0
    fi

    for svc in vmtoolsd vmware-vmblock-fuse.service; do
      /usr/bin/sudo ${pkgs.systemd}/bin/systemctl enable --now "$svc" 2>/dev/null \
        || echo "WARNING: could not enable $svc"
    done
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
