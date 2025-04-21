{ config, pkgs, lib, ... }:

{
  home.file.".xinitrc".text = ''
    #!/bin/sh
    # /etc/X11/xinit/xinitrc
    
    # global xinitrc file, used by all X sessions started by xinit (startx)
    # invoke global X session script
    . /etc/X11/Xsession

    export DISPLAY=:0
    export XAUTHORITY="${config.home.homeDirectory}/.Xauthority"
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY

    # VMware
    if command -v vmware-user-suid-wrapper >/dev/null; then
      vmware-user-suid-wrapper &
    fi
  '';

  xsession = {
    enable = true;
  };

  imports = [
    (import ./i3 { inherit config pkgs lib; })
  ];
}
