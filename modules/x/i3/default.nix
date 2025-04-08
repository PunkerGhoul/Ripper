{ config, pkgs, lib, ...}:

let
  modifier = config.xsession.windowManager.i3.config.modifier;
in {
  home.file.".config/i3/scripts/lock".source = ./scripts/lock;

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      bars = [];
      terminal = "kitty";
      fonts = {
        names = [ "pango" ];
        style = "monospace";
        size = 8.0;
      };
      window = {
        border = 0;
        hideEdgeBorders = "none";
      };
      floating = {
        border = 0;
        # Use Mouse+$mod to drag floating windows to their wanted position
      };
      gaps = {
        inner = 8;
        outer = -8;
      };
      startup = [
        # Start XDG autostart .desktop files using dex. See also
        # https://wiki.archlinux.org/index.php/XDG_Autostart
        {
          command = "${pkgs.dex}/bin/dex --autostart --environment i3";
          notification = false;
        }
        # The combination of xss-lock, nm-applet and pactl is a popular choice, so
        # they are included here as an example. Modify as you see fit.
        # xss-lock grabs a logind suspend inhibit lock and will use i3lock to lock the
        # screen before suspend. Use loginctl lock-session to lock your screen.
        {
        #  command = "xss-lock --transfer-sleep-lock -- i3lock --nofork";
        #  command = "xss-lock --transfer-sleep-lock -- $HOME/.config/i3/scripts/lock";
          command = "$HOME/.config/i3/scripts/lock";
          notification = false;
        }
        # NetworkManager is the most popular way to manage wireless networks on Linux,
        # and nm-applet is a desktop environment-independent system tray GUI for it.
        {
          command = "${pkgs.networkmanagerapplet}/bin/nm-applet";
          notification = false;
        }
        # Start VMware User
        {
          command = "vmware-user";
          notification = false;
        }
        {
          command = "vmware-user-suid-wrapper";
          notification = false;
        }
        # Display Resolution
        {
          command = "xrandr --output Virtual1 --mode 1920x1080";
          always = true;
        }
        {
          command = "xrandr --setprovideroutputsource modesetting NVIDIA-0";
          always = true;
        }
        {
          command = "xrandr --auto";
          always = true;
        }
        # Display Wallpaper
        {
          command = "${pkgs.feh}/bin/feh --bg-fill $HOME/Pictures/Wallpapers/cyberpunk.jpg";
          always = true;
        }
        # Transparency with picom compositor
        {
          command = "${pkgs.picom}/bin/picom -f";
          always = true;
        }
        # Polybar
        {
          command = "$HOME/.config/polybar/launch.sh --cuts";
          notification = false;
          always = true;
        }
        {
          command = "$HOME/.local/bin/polybar-reload";
          notification = false;
          always = true;
        }
        # Dunst
        {
          command = "dunst -config $HOME/.config/dunst/dunstrc";
          notification = false;
          always = true;
        }
        # FlameShot
        {
          command = "flameshot";
          notification = false;
          always = true;
        }
        # Enable NumLock on Boot
        {
          command = "${pkgs.numlockx}/bin/numlockx on";
          notification = false;
          always = true;
        }
      ];
      keybindings = lib.mkOptionDefault {
        # Menu
        "${modifier}+d" = "exec \"${pkgs.rofi}/bin/rofi -modi run,run -show run\"";
        # LockScreen
        "${modifier}+x" = "exec $HOME/.config/i3/scripts/lock";
        # Print Screen with FlameShot
        "Print" = "flameshot gui";
        # Resize Mode
        "${modifier}+r" = "mode \"resize\"";
        # Reload the configuration file
        "${modifier}+Shift+c" = "reload";
        # Restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
        "${modifier}+Shift+r" = "restart";
        # Exit i3 (logs you out of your X session)
        "${modifier}+Shift+e" = ''
          exec "${pkgs.i3}/bin/i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'"'';
        # kill Focused Window
        "${modifier}+Shift+q" = "kill";
        # Workspaces
        ## Switch to workspace
        "${modifier}+0" = "workspace number 10";
        "${modifier}+1" = "workspace number 1";
        "${modifier}+2" = "workspace number 2";
        "${modifier}+3" = "workspace number 3";
        "${modifier}+4" = "workspace number 4";
        "${modifier}+5" = "workspace number 5";
        "${modifier}+6" = "workspace number 6";
        "${modifier}+7" = "workspace number 7";
        "${modifier}+8" = "workspace number 8";
        "${modifier}+9" = "workspace number 9";
        ## Move focused container to workspace
        "${modifier}+Shift+0" = "move container to workspace number 10";
        "${modifier}+Shift+1" = "move container to workspace number 1";
        "${modifier}+Shift+2" = "move container to workspace number 2";
        "${modifier}+Shift+3" = "move container to workspace number 3";
        "${modifier}+Shift+4" = "move container to workspace number 4";
        "${modifier}+Shift+5" = "move container to workspace number 5";
        "${modifier}+Shift+6" = "move container to workspace number 6";
        "${modifier}+Shift+7" = "move container to workspace number 7";
        "${modifier}+Shift+8" = "move container to workspace number 8";
        "${modifier}+Shift+9" = "move container to workspace number 9";
        # Focus
        ## Default
        "${modifier}+j" = "focus left";
        "${modifier}+k" = "focus down";
        "${modifier}+l" = "focus up";
        "${modifier}+semicolon" = "focus right";
        ### Alternatively, you can use the cursor keys:
        "${modifier}+Left" = "focus left";
        "${modifier}+Down" = "focus down";
        "${modifier}+Up" = "focus up";
        "${modifier}+Right" = "focus right";
        ## Move focused window
        "${modifier}+Shift+j" = "move left";
        "${modifier}+Shift+k" = "move down";
        "${modifier}+Shift+l" = "move up";
        "${modifier}+Shift+semicolon" = "move right";
        ### Alternatively, you can use the cursor keys:
        "${modifier}+Shift+Left" = "move left";
        "${modifier}+Shift+Down" = "move down";
        "${modifier}+Shift+Up" = "move up";
        "${modifier}+Shift+Right" = "move right";
        # Split
        ## Horizontal Orientation
        "${modifier}+h" = "split h";
        ## Vertical Orientation
        "${modifier}+v" = "split v";
        # FullScreen mode for the focused container
        "${modifier}+f" = "fullscreen toggle";
        # Container layout (stacked, tabbed, toggle split)
        "${modifier}+s" = "layout stacking";
        "${modifier}+w" = "layout tabbed";
        "${modifier}+e" = "layout toggle split";
        # Toggle tiling / floating
        "${modifier}+Shift+space" = "floating toggle";
        # Change focus between tiling / floating windows
        "${modifier}+space" = "focus mode_toggle";
        # Container
        ## Focus the parent container
        "${modifier}+a" = "focus parent";
        ## Focus the child container
        "${modifier}+c" = "focus child";
      };
      #keycodebindings = {
      #  "${modifier}+40" = "exec \"rofi -modi run,run -show run\"";
      #};
      modes = {
        # Resize window (you can also use the mouse for that)
        resize = {
          # These bindings trigger as soon as you enter the resize mode
          # Pressing left will shrink the window’s width.
          # Pressing right will grow the window’s width.
          # Pressing up will shrink the window’s height.
          # Pressing down will grow the window’s height.
          j = "resize shrink width 10 px or 10 ppt";
          k = "resize grow height 10 px or 10 ppt";
          l = "resize shrink height 10 px or 10 ppt";
          semicolon = "resize grow width 10 px or 10 ppt";
          # same bindings, but for the arrow keys
          Left = "resize shrink width 10 px or 10 ppt";
          Down = "resize grow height 10 px or 10 ppt";
          Up = "resize shrink height 10 px or 10 ppt";
          Right = "resize grow width 10 px or 10 ppt";
          # back to normal: Enter or Escape or $mod+r
          Return = "mode \"default\"";
          Escape = "mode \"default\"";
          "${modifier}+r" = "mode \"default\"";
        };
      };
      defaultWorkspace = "workspace number 1";
      # Allocate applications to workspaces
      assigns = {
        "2" = [{ class = "LibreWolf"; }];
        "3" = [
          { class = "burp-StartBurp"; }
          { class = "org-zaproxy-zap-ZAP"; }
        ];
        "4" = [{ class = "obsidian"; }];
      };
    };
    extraConfig = builtins.readFile ./config;
  };
}
