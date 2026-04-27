{ config, pkgs, lib, logoutScript ? null, ... }:

let
  theme = "cuts";

  polybarPackage = pkgs.polybar.override {
    alsaSupport = true;
    githubSupport = true;
    mpdSupport = true;
    pulseSupport = true;
    iwSupport = false;
    nlSupport = true;
    # The active themes do not use internal/i3. Keeping this off avoids the
    # current polybarFull/jsoncpp link regression in nixpkgs-unstable.
    i3Support = false;
  };

  featherFont   = import ./feather-font.nix { inherit pkgs; };
  polybarReload = import ./polybar-reload { inherit pkgs; };
  resolvedLogoutScript =
    if logoutScript != null then
      logoutScript
    else
      pkgs.writeShellScript "ripper-logout-fallback" ''
        ${pkgs.i3}/bin/i3-msg exit >/dev/null 2>&1 || true
      '';
  polybarTheme  = import ./polybar-themes   { inherit pkgs theme polybarPackage; logoutScript = resolvedLogoutScript; };
  polybarStartScript = ''
    #!${pkgs.runtimeShell}
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-polybar.log"
    config="$HOME/.config/polybar/${theme}/config.ini"
    runtime_config="$runtime_dir/ripper-polybar-${theme}.ini"

    {
      echo "ripper-polybar-start: $(${pkgs.coreutils}/bin/date)"

      if [ -z "''${DISPLAY:-}" ]; then
        echo "DISPLAY is not set"
        exit 0
      fi

      exec 9>"$runtime_dir/ripper-polybar-start.lock"
      if ! ${pkgs.util-linux}/bin/flock -n 9; then
        echo "polybar start already running"
        exit 0
      fi

      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        [ -r "$config" ] && break
        ${pkgs.coreutils}/bin/sleep 0.05
      done
      if [ ! -r "$config" ]; then
        echo "missing config: $config"
        exit 0
      fi

      i3_ready=false
      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if ${pkgs.i3}/bin/i3-msg -t get_workspaces >/dev/null 2>&1; then
          i3_ready=true
          break
        fi
        ${pkgs.coreutils}/bin/sleep 0.05
      done
      if [ "$i3_ready" != "true" ]; then
        echo "i3 IPC is not ready; refusing to start polybar outside i3"
        exit 0
      fi

      read_i3_geometry() {
        ${pkgs.i3}/bin/i3-msg -t get_workspaces 2>/dev/null | ${pkgs.jq}/bin/jq -r '
          ([.[] | select(.focused)] + [.[] | select(.visible)] + .)[0]
          | select(.rect.width > 0 and .rect.height > 0)
          | "\(.rect.width) \(.rect.height) \(.rect.x) \(.rect.y) \(.output // "")"
        '
      }

      read_geometry() {
        read_i3_geometry
      }

      last_geometry=""
      stable_samples=0
      geometry=""
      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40; do
        current_geometry="$(read_geometry || true)"

        if [ -n "$current_geometry" ] && [ "$current_geometry" = "$last_geometry" ]; then
          stable_samples=$((stable_samples + 1))
        else
          stable_samples=0
          last_geometry="$current_geometry"
        fi

        if [ -n "$current_geometry" ]; then
          geometry="$current_geometry"
        fi

        [ "$stable_samples" -ge 6 ] && break
        ${pkgs.coreutils}/bin/sleep 0.1
      done

      set -- $geometry
      screen_width="''${1:-}"
      screen_height="''${2:-}"
      screen_x="''${3:-0}"
      screen_y="''${4:-0}"
      screen_monitor="''${5:-}"
      case "$screen_width" in
        *[!0-9]*)
          screen_width=""
          ;;
      esac
      case "$screen_x" in
        -|*[!0-9-]*)
          screen_x="0"
          ;;
      esac

      if [ -n "$screen_width" ]; then
        runtime_config_tmp="$runtime_config.$$"
        if [ -n "$screen_monitor" ]; then
          if ${pkgs.gnused}/bin/sed -E \
            -e "0,/^monitor =.*/s//monitor = $screen_monitor/" \
            -e "0,/^width = .*/s//width = $screen_width/" \
            -e "0,/^offset-x = .*/s//offset-x = 0/" \
            "$config" > "$runtime_config_tmp"; then
            ${pkgs.coreutils}/bin/mv "$runtime_config_tmp" "$runtime_config"
            config="$runtime_config"
            echo "polybar runtime geometry from i3: width=$screen_width height=$screen_height x=$screen_x y=$screen_y monitor=$screen_monitor"
          else
            ${pkgs.coreutils}/bin/rm -f "$runtime_config_tmp"
            echo "could not generate runtime polybar config; using source config"
          fi
        elif ${pkgs.gnused}/bin/sed -E \
          -e "0,/^width = .*/s//width = $screen_width/" \
          -e "0,/^offset-x = .*/s//offset-x = 0/" \
          "$config" > "$runtime_config_tmp"; then
          ${pkgs.coreutils}/bin/mv "$runtime_config_tmp" "$runtime_config"
          config="$runtime_config"
          echo "polybar runtime geometry: width=$screen_width height=$screen_height x=$screen_x y=$screen_y monitor=auto"
        else
          ${pkgs.coreutils}/bin/rm -f "$runtime_config_tmp"
          echo "could not generate runtime polybar config; using source config"
        fi
      else
        echo "could not detect i3 workspace geometry; refusing to start polybar"
        exit 0
      fi

      for _ in 1 2 3 4 5; do
        ${pkgs.psmisc}/bin/killall -q polybar 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          ${pkgs.procps}/bin/pgrep -u "$UID" -x polybar >/dev/null 2>&1 || break
          ${pkgs.coreutils}/bin/sleep 0.05
        done
        if ${pkgs.procps}/bin/pgrep -u "$UID" -x polybar >/dev/null 2>&1; then
          ${pkgs.procps}/bin/pkill -KILL -u "$UID" -x polybar 2>/dev/null || true
          ${pkgs.coreutils}/bin/sleep 0.03
        fi

        ${polybarPackage}/bin/polybar -q top -c "$config" &
        ${polybarPackage}/bin/polybar -q bottom -c "$config" &

        ${pkgs.coreutils}/bin/sleep 0.2
        running="$(${pkgs.procps}/bin/pgrep -u "$UID" -x polybar 2>/dev/null | ${pkgs.coreutils}/bin/wc -l | ${pkgs.coreutils}/bin/tr -d ' ' || true)"
        if [ "''${running:-0}" -ge 2 ]; then
          echo "polybar started: $running processes"
          exit 0
        fi

        echo "polybar did not stay up; retrying"
      done
    } > "$log" 2>&1
  '';
  polybarResizeWatchScript = ''
    #!${pkgs.runtimeShell}
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-polybar-resize.log"
    exec >>"$log" 2>&1

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    exec 9>"$runtime_dir/ripper-polybar-resize.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "ripper-polybar-resize-watch: already running"
      exit 0
    fi

    echo "ripper-polybar-resize-watch: start $(${pkgs.coreutils}/bin/date) DISPLAY=''${DISPLAY:-unset}"
    exec ${polybarReload}/bin/polybar-reload
  '';
in
{
  home.activation.refresh-polybar-runtime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    if [ -n "$user_name" ]; then
      ${pkgs.procps}/bin/pkill -u "$user_name" -x polybar-reload 2>/dev/null || true
    fi

    if [ -n "''${DISPLAY:-}" ] && [ -x "$HOME/.local/bin/ripper-polybar-start" ]; then
      "$HOME/.local/bin/ripper-polybar-start" >/dev/null 2>&1 &
      if [ -x "$HOME/.local/bin/ripper-polybar-resize-watch" ]; then
        (
          ${pkgs.coreutils}/bin/sleep 0.15
          "$HOME/.local/bin/ripper-polybar-resize-watch" >/dev/null 2>&1
        ) &
      fi
    fi
  '';

  home.packages = [
    pkgs.nerd-fonts.iosevka
    pkgs.nerd-fonts.symbols-only
  ];

  home.file.".config/fontconfig/conf.d/99-feather.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <dir>${featherFont}/share/fonts/truetype</dir>
    </fontconfig>
  '';

  home.file.".config/polybar" = {
    source = polybarTheme;
    recursive = true;
  };

  home.file.".local/bin/polybar-reload" = {
    source = "${polybarReload}/bin/polybar-reload";
    executable = true;
  };

  home.file.".local/bin/ripper-polybar-start" = {
    text = polybarStartScript;
    executable = true;
  };

  home.file.".local/bin/ripper-polybar-resize-watch" = {
    text = polybarResizeWatchScript;
    executable = true;
  };
}
