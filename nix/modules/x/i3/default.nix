{ config, pkgs, lib, logoutScript, ...}:

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
  rofiLauncher = pkgs.writeShellScript "ripper-rofi-drun" ''
    export PATH="${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.nix-profile/bin:${config.home.homeDirectory}/.local/state/nix/profiles/profile/bin:$PATH"
    export XDG_DATA_DIRS="${config.home.homeDirectory}/.local/share:${config.home.homeDirectory}/.nix-profile/share:${config.home.homeDirectory}/.local/state/nix/profiles/profile/share:''${XDG_DATA_DIRS:-}"
    exec ${pkgs.rofi}/bin/rofi -modi drun,run -show drun
  '';
  floatingToggleScript = pkgs.writeShellScript "ripper-i3-floating-toggle" ''
    set -eu

    state="$(${pkgs.i3}/bin/i3-msg -t get_tree | ${pkgs.jq}/bin/jq -r '
      recurse(.nodes[]?, .floating_nodes[]?)
      | select(.focused == true)
      | .floating // "auto_off"
    ')"

    case "$state" in
      user_on|auto_on)
        exec ${pkgs.i3}/bin/i3-msg 'floating disable'
        ;;
    esac

    geometry="$(${pkgs.i3}/bin/i3-msg -t get_workspaces | ${pkgs.jq}/bin/jq -r '
      ([.[] | select(.focused)] + [.[] | select(.visible)] + .)[0].rect
      | "\(.width) \(.height)"
    ')"
    set -- $geometry
    width="''${1:-1280}"
    height="''${2:-720}"

    case "$width" in
      ""|*[!0-9]*)
        width=1280
        ;;
    esac
    case "$height" in
      ""|*[!0-9]*)
        height=720
        ;;
    esac

    target_width=$((width * 75 / 100))
    target_height=$((height * 75 / 100))

    exec ${pkgs.i3}/bin/i3-msg "floating enable, resize set $target_width px $target_height px, move position center"
  '';
  kittyLauncher = "${config.home.homeDirectory}/.local/bin/ripper-kitty";
  confirmLogoutScript = pkgs.writeShellScript "ripper-confirm-logout" ''
    exec ${pkgs.i3}/bin/i3-nagbar \
      -t warning \
      -m "Exit this i3 session and return to SDDM?" \
      -B "Yes, logout" "${logoutScript}"
  '';
  polkitAgentStartScript = pkgs.writeShellScript "ripper-polkit-agent-start" ''
    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    if [ -n "$user_name" ] && ${pkgs.procps}/bin/pgrep -u "$user_name" -f 'lxqt-policykit-agent' >/dev/null 2>&1; then
      exit 0
    fi

    # Usa el agente LXQt personalizado desde home-manager o nixpkgs
    for agent in \
      ~/.nix-profile/lib/lxqt-policykit-agent/lxqt-policykit-agent \
      ${pkgs.lxqt.lxqt-policykit}/lib/lxqt-policykit-agent/lxqt-policykit-agent \
      /usr/lib/lxqt-policykit-agent/lxqt-policykit-agent \
      /usr/libexec/lxqt-policykit-agent; do
      if [ -x "$agent" ]; then
        "$agent" >/dev/null 2>&1 &
        exit 0
      fi
    done
  '';
  sessionStartScript = ''
    #!${pkgs.runtimeShell}
    set -u

    runtime_dir="''${XDG_RUNTIME_DIR:-}"
    if [ -z "$runtime_dir" ]; then
      runtime_dir="/tmp/ripper-runtime-$UID"
      mkdir -p "$runtime_dir"
      chmod 700 "$runtime_dir"
      export XDG_RUNTIME_DIR="$runtime_dir"
    fi

    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    if [ -n "$user_name" ] && ${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 >/dev/null 2>&1; then
      echo "Ripper session: refusing to start while another i3 process exists for $user_name" >&2
      exit 1
    fi

    export XDG_CURRENT_DESKTOP=i3
    export XDG_SESSION_DESKTOP=ripper
    export XDG_SESSION_TYPE=x11
    export DESKTOP_SESSION=ripper

    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment --systemd \
        DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE DESKTOP_SESSION >/dev/null 2>&1 || true
    fi

    if ${pkgs.i3}/bin/i3-msg -t get_version >/dev/null 2>&1; then
      echo "Ripper session: refusing to start a second i3 instance on DISPLAY=''${DISPLAY:-unset}" >&2
      exit 1
    fi

    if [ -x "$HOME/.local/bin/ripper-picom-start" ]; then
      "$HOME/.local/bin/ripper-picom-start" >/dev/null 2>&1 &
    fi

    "$HOME/.local/bin/ripper-polkit-agent-start" >/dev/null 2>&1 \
      || ${polkitAgentStartScript} >/dev/null 2>&1 \
      || true

    ${pkgs.dunst}/bin/dunst -config "$HOME/.config/dunst/dunstrc" >/dev/null 2>&1 &
    command -v flameshot >/dev/null 2>&1 && flameshot >/dev/null 2>&1 &
    ${pkgs.numlockx}/bin/numlockx on >/dev/null 2>&1 || true
    ${pkgs.networkmanagerapplet}/bin/nm-applet >/dev/null 2>&1 &

    exec ${pkgs.i3}/bin/i3 -c "$HOME/.config/i3/config"
  '';
in {

  home.file = {
    ".local/bin/ripper-session-start" = {
      text = sessionStartScript;
      executable = true;
    };

    ".local/bin/ripper-i3-floating-toggle" = {
      source = floatingToggleScript;
      executable = true;
    };

    ".local/bin/ripper-polkit-agent-start" = {
      source = polkitAgentStartScript;
      executable = true;
    };

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
        [ "$focusedwindow" != "$($xdotool_bin getactivewindow)" ] && $xdotool_bin windowfocus $focusedwindow
      '';
      executable = true;
    };
  };

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      bars = [];
      terminal = kittyLauncher;
      fonts = {
        names = [ "pango" ];
        style = "monospace";
        size = 8.0;
      };
      window = {
        titlebar = false;
        border = 2;
        hideEdgeBorders = "none";
      };
      floating = {
        titlebar = false;
        border = 2;
        # Use Mouse+$mod to drag floating windows to their wanted position
      };
      gaps = {
        inner = 8;
        outer = 4;
      };
      startup = [
        {
          command = "$HOME/.local/bin/ripper-wallpaper-start";
          notification = false;
          always = false;
        }
        {
          command = "$HOME/.local/bin/ripper-vmware-user";
          notification = false;
          always = true;
        }
        {
          command = "$HOME/.local/bin/ripper-vmware-auto-resize";
          notification = false;
          always = true;
        }
        {
          command = "$HOME/.local/bin/ripper-polybar-resize-watch";
          notification = false;
          always = true;
        }
      ];
      keybindings = lib.mkForce {
        # Menu
        "${modifier}+d" = "exec --no-startup-id ${rofiLauncher}";
        "${modifier}+b" = "exec --no-startup-id ${pkgs.librewolf}/bin/librewolf -P Pentesting";
        "${modifier}+Return" = "exec --no-startup-id ${kittyLauncher}";
        "XF86AudioRaiseVolume" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --allow-boost --increase 5";
        "XF86AudioLowerVolume" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --decrease 5";
        "XF86AudioMute" = "exec --no-startup-id ${pkgs.pamixer}/bin/pamixer --toggle-mute";
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
        "${modifier}+Shift+e" = "exec --no-startup-id ${confirmLogoutScript}";
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
        "${modifier}+v" = "focus right; split v";
        # FullScreen mode for the focused container
        "${modifier}+f" = "fullscreen toggle";
        # Container layout (stacked, tabbed, toggle split)
        "${modifier}+s" = "layout stacking";
        "${modifier}+w" = "layout tabbed";
        "${modifier}+e" = "layout toggle split";
        # Toggle tiling / floating
        "${modifier}+Shift+space" = "exec --no-startup-id $HOME/.local/bin/ripper-i3-floating-toggle";
        # Change focus between tiling / floating windows
        "${modifier}+space" = "focus mode_toggle";
        # Scratchpad
        "${modifier}+Shift+minus" = "move scratchpad";
        "${modifier}+minus" = "scratchpad show";
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
    extraConfig = ''
      focus_follows_mouse yes
      mouse_warping none
      default_orientation horizontal
      workspace_layout default
      default_border pixel 2
      default_floating_border pixel 2
      hide_edge_borders none
      client.focused          #8e5cff #8e5cff #f7f0ff #b983ff #b983ff
      client.focused_inactive #4b2f6f #4b2f6f #d9c7ff #6f42a8 #6f42a8
      client.unfocused        #241833 #241833 #a68ac7 #3a2653 #3a2653
      client.urgent           #d75f8f #d75f8f #ffffff #d75f8f #d75f8f
      client.placeholder      #1b1326 #1b1326 #d9c7ff #1b1326 #1b1326
    '';
  };
}
