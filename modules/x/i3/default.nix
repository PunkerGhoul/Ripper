{ config, pkgs, lib, ...}:

let
  modifier = config.xsession.windowManager.i3.config.modifier;
  hostPamLibraryPath = pkgs.lib.concatStringsSep ":" [
    "/usr/lib"
    "/usr/lib64"
    "/lib"
    "/lib64"
    "/usr/lib/x86_64-linux-gnu"
    "/lib/x86_64-linux-gnu"
    "/usr/lib/aarch64-linux-gnu"
    "/lib/aarch64-linux-gnu"
  ];

  i3lock-color = pkgs.stdenv.mkDerivation rec {
    pname = "i3lock-color";
    version = "2.13.c.5";

    src = pkgs.fetchFromGitHub {
      owner = "Raymo111";
      repo = "i3lock-color";
      rev = version;
      hash = "sha256-fuLeglRif2bruyQRqiL3nm3q6qxoHcPdVdL+QjGBR/k=";
    };

    nativeBuildInputs = with pkgs; [
      autoconf
      automake
      pkg-config
      makeWrapper
    ];

    buildInputs = with pkgs; [
      pam
      cairo
      libev
      libxkbcommon
      libjpeg
      giflib
      libxcb
      libxcb-util
      libxcb-image
      xcbutilxrm
      libxcb-keysyms
    ];

    preConfigure = ''
      autoreconf -fiv
      mkdir -p _build
      cd _build
    '';

    configureScript = "../configure";

    buildPhase = ''
      runHook preBuild
      make
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 i3lock $out/bin/.i3lock-wrapped
      makeWrapper $out/bin/.i3lock-wrapped $out/bin/i3lock \
        --prefix LD_LIBRARY_PATH : ${hostPamLibraryPath}
      runHook postInstall
    '';
  };

  lockScript = builtins.replaceStrings
    [ "{{i3lockBin}}" ]
    [ "${i3lock-color}/bin" ]
    (builtins.readFile ./scripts/lock);
  fastAutostart = pkgs.writeShellScript "ripper-i3-autostart" ''
    (
      [ -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ] \
        && /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &

      ${pkgs.feh}/bin/feh --bg-center --geometry 1920x1080 "$HOME/Pictures/Wallpapers/cyberpunk.jpg" &
      "$HOME/.local/bin/ripper-polybar-start" &
      "$HOME/.local/bin/polybar-reload" &
      ${pkgs.dunst}/bin/dunst -config "$HOME/.config/dunst/dunstrc" &
      command -v flameshot >/dev/null 2>&1 && flameshot &
      ${pkgs.numlockx}/bin/numlockx on &
      ${pkgs.networkmanagerapplet}/bin/nm-applet &
    ) >/tmp/ripper-i3-autostart.log 2>&1 &
  '';
in {

  home.file = {
    ".config/i3/scripts/lock" = {
      text = lockScript;
      executable = true;
    };

    ".config/i3/scripts/flameshot" = {
      text = ''
        #!/usr/bin/sh

        xdotool_bin="${pkgs.xdotool}/bin/xdotool"
        focusedwindow=$($xdotool_bin getactivewindow)
        /usr/bin/flameshot gui  >/dev/null
        [ "$focusedwindow" = "$($xdotool_bin getactivewindow)" ] && $xdotool_bin windowfocus $focusedwindow
      '';
      executable = true;
    };
  };

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      bars = [];
      terminal = "${config.programs.kitty.package}/bin/kitty";
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
        {
          command = toString fastAutostart;
          notification = false;
          always = true;
        }
      ];
      keybindings = lib.mkOptionDefault {
        # Menu
        "${modifier}+d" = ''exec "env PATH=${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.nix-profile/bin:${config.home.homeDirectory}/.local/state/nix/profiles/profile/bin:$PATH XDG_DATA_DIRS=${config.home.homeDirectory}/.local/share:${config.home.homeDirectory}/.nix-profile/share:${config.home.homeDirectory}/.local/state/nix/profiles/profile/share:$XDG_DATA_DIRS ${pkgs.rofi}/bin/rofi -modi drun,run -show drun"'';
        "XF86AudioRaiseVolume" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --allow-boost --increase 5";
        "XF86AudioLowerVolume" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --decrease 5";
        "XF86AudioMute" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --toggle-mute";
        "XF86AudioMicMute" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --default-source --toggle-mute";
        # LockScreen
        "${modifier}+x" = "exec $HOME/.config/i3/scripts/lock";
        # Print Screen with FlameShot
        "Print" = "exec --no-startup-id $HOME/.config/i3/scripts/flameshot";
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
        "2" = [
          { class = "Navigator"; }
          { class = "librewolf"; }
        ];
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
