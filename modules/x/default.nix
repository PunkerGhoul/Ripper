{ config, pkgs, lib, ... }:

{
  home.file.".xinitrc".text = ''
    #!/bin/sh
    # /etc/X11/xinit/xinitrc
    
    # global xinitrc file, used by all X sessions started by xinit (startx)
    # invoke global X session script
    . /etc/X11/Xsession
  '';

  xsession = {
    enable = true;
  };

  imports = [
    (import ./i3 { inherit config pkgs lib; })
  ];
}
