{ config, pkgs, lib, ... }:

{
  home.activation.install-xorg = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (builtins.readFile ./scripts/install-xorg.sh);

  home.activation.install-vmware-tools = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (builtins.replaceStrings
      [ "{{gnuGrep}}" "{{systemd}}" "{{pciUtils}}" ]
      [ "${pkgs.gnugrep}" "${pkgs.systemd}" "${pkgs.pciutils}" ]
      (builtins.readFile ./scripts/install-vmware-tools.sh));

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
      ExecStart = toString (pkgs.writeShellScript "vmware-auto-resize"
        (builtins.replaceStrings
          [ "{{coreUtils}}" "{{xev}}" "{{xrandr}}" "{{gawk}}" ]
          [ "${pkgs.coreutils}" "${pkgs.xev}" "${pkgs.xrandr}" "${pkgs.gawk}" ]
          (builtins.readFile ./scripts/vmware-auto-resize.sh)));
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
