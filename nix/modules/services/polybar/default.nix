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
    geometry_state="$runtime_dir/ripper-polybar-randr.geometry"
    force_restart=false
    hard_restart=false
    case "''${1:-}" in
      --force)
        force_restart=true
        ;;
      --hard)
        force_restart=true
        hard_restart=true
        ;;
    esac

    {
      echo "ripper-polybar-start: $(${pkgs.coreutils}/bin/date)"

      if [ -z "''${DISPLAY:-}" ]; then
        echo "DISPLAY is not set"
        exit 0
      fi

      exec 9>"$runtime_dir/ripper-polybar-start.lock"
      echo "waiting for polybar restart lock"
      ${pkgs.util-linux}/bin/flock 9
      echo "polybar restart lock acquired"

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

      read_xwininfo_geometry() {
        ${pkgs.xwininfo}/bin/xwininfo "$@" 2>/dev/null | ${pkgs.gawk}/bin/awk '
          /Absolute upper-left X:/ { x=$NF }
          /Absolute upper-left Y:/ { y=$NF }
          /^  Width:/ { w=$NF }
          /^  Height:/ { h=$NF }
          END {
            if (w + 0 > 0 && h + 0 > 0) {
              print (w + 0) "x" (h + 0) "+" (x + 0) "+" (y + 0)
            } else {
              exit 1
            }
          }
        '
      }

      read_active_geometry() {
        active_window="$(${pkgs.xdotool}/bin/xdotool getactivewindow 2>/dev/null || true)"
        case "$active_window" in
          ""|*[!0-9]*)
            return 1
            ;;
        esac

        read_xwininfo_geometry -id "$active_window"
      }

      read_effective_geometry() {
        read_active_geometry \
          || read_xwininfo_geometry -root \
          || return 1
      }

      write_runtime_config() {
        geometry="$1"
        case "$geometry" in
          ""|unknown)
            return 1
            ;;
          *x*+*)
            ;;
          *)
            return 1
            ;;
        esac

        width="''${geometry%%x*}"
        rest="''${geometry#*x}"
        rest="''${rest#*+}"
        offset_x="''${rest%%+*}"

        case "$width" in
          ""|*[!0-9]*)
            return 1
            ;;
        esac
        case "$offset_x" in
          ""|-|*[!0-9-]*)
            return 1
            ;;
        esac

        runtime_config_tmp="$runtime_config.$$"
        if ${pkgs.gnused}/bin/sed -E \
          -e "0,/^monitor =.*/s//monitor = /" \
          -e "0,/^width = .*/s//width = $width/" \
          -e "0,/^offset-x = .*/s//offset-x = $offset_x/" \
          "$config" > "$runtime_config_tmp"; then
          ${pkgs.coreutils}/bin/mv "$runtime_config_tmp" "$runtime_config"
          echo "$geometry" > "$geometry_state"
          config="$runtime_config"
          echo "polybar runtime config geometry=$geometry width=$width offset-x=$offset_x"
          return 0
        fi

        ${pkgs.coreutils}/bin/rm -f "$runtime_config_tmp"
        return 1
      }

      geometry=""
      if [ "$hard_restart" != "true" ]; then
        geometry="$(${pkgs.coreutils}/bin/cat "$geometry_state" 2>/dev/null || true)"
      fi
      if [ -z "$geometry" ]; then
        geometry="$(read_effective_geometry || true)"
      fi
      write_runtime_config "$geometry" || true

      polybar_count() {
        ${pkgs.procps}/bin/pgrep -u "$UID" -x polybar 2>/dev/null \
          | ${pkgs.coreutils}/bin/wc -l \
          | ${pkgs.coreutils}/bin/tr -d ' ' || true
      }

      polybar_window_count() {
        ${pkgs.xwininfo}/bin/xwininfo -root -tree 2>/dev/null | ${pkgs.gawk}/bin/awk '
          /"polybar-top/ { top=1 }
          /"polybar-bottom/ { bottom=1 }
          END { print top + bottom }
        '
      }

      ensure_two_polybars() {
        [ "$(polybar_count)" -ge 2 ] || return 1
        [ "$(polybar_window_count)" -ge 2 ] || return 1
      }

      restart_polybar_ipc() {
        ensure_two_polybars || return 1
        ${polybarPackage}/bin/polybar-msg cmd restart >/dev/null 2>&1 || return 1
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          ensure_two_polybars && return 0
          ${pkgs.coreutils}/bin/sleep 0.05
        done
        return 1
      }

      if [ "$force_restart" = "true" ] && [ "$hard_restart" != "true" ] && restart_polybar_ipc; then
        echo "polybar restarted through IPC"
        exit 0
      fi

      if [ "$force_restart" != "true" ] && ensure_two_polybars; then
        echo "polybar already running"
        exit 0
      fi

      ${pkgs.psmisc}/bin/killall -q polybar 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ "$(polybar_count)" -eq 0 ] && break
        ${pkgs.coreutils}/bin/sleep 0.05
      done
      if [ "$(polybar_count)" -ne 0 ]; then
        ${pkgs.procps}/bin/pkill -KILL -u "$UID" -x polybar 2>/dev/null || true
        ${pkgs.coreutils}/bin/sleep 0.03
      fi

      ${polybarPackage}/bin/polybar -q top -c "$config" &
      ${polybarPackage}/bin/polybar -q bottom -c "$config" &

      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        running="$(polybar_count)"
        windows="$(polybar_window_count)"
        if [ "''${running:-0}" -ge 2 ] && [ "''${windows:-0}" -ge 2 ]; then
          echo "polybar started: $running processes $windows windows"
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 0.05
      done

      echo "polybar did not start completely; running=$(polybar_count) windows=$(polybar_window_count)"
      exit 0
    } > "$log" 2>&1
  '';
  polybarResizeWatchScript = ''
    #!${pkgs.runtimeShell}
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-polybar-resize.log"
    debounce_stamp="$runtime_dir/ripper-polybar-randr.stamp"
    debounce_lock="$runtime_dir/ripper-polybar-randr.debounce"
    geometry_state="$runtime_dir/ripper-polybar-randr.geometry"
    exec >>"$log" 2>&1

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    exec 9>"$runtime_dir/ripper-polybar-resize.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "ripper-polybar-resize-watch: already running; requesting polybar IPC restart"
      "$HOME/.local/bin/ripper-polybar-start" --force
      exit 0
    fi

    echo "ripper-polybar-resize-watch: start $(${pkgs.coreutils}/bin/date) DISPLAY=''${DISPLAY:-unset}"

    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
      ${pkgs.i3}/bin/i3-msg -t get_workspaces >/dev/null 2>&1 && break
      ${pkgs.coreutils}/bin/sleep 0.1
    done

    "$HOME/.local/bin/ripper-polybar-start" --hard

    ${pkgs.coreutils}/bin/rmdir "$debounce_lock" 2>/dev/null || true

    polybar_count() {
      ${pkgs.procps}/bin/pgrep -u "$UID" -x polybar 2>/dev/null \
        | ${pkgs.coreutils}/bin/wc -l \
        | ${pkgs.coreutils}/bin/tr -d ' ' || true
    }

    polybar_window_count() {
      ${pkgs.xwininfo}/bin/xwininfo -root -tree 2>/dev/null | ${pkgs.gawk}/bin/awk '
        /"polybar-top/ { top=1 }
        /"polybar-bottom/ { bottom=1 }
        END { print top + bottom }
      '
    }

    ensure_two_polybars() {
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ "$(polybar_count)" -ge 2 ] && [ "$(polybar_window_count)" -ge 2 ] && return 0
        ${pkgs.coreutils}/bin/sleep 0.05
      done
      return 1
    }

    read_xwininfo_geometry() {
      ${pkgs.xwininfo}/bin/xwininfo "$@" 2>/dev/null | ${pkgs.gawk}/bin/awk '
        /Absolute upper-left X:/ { x=$NF }
        /Absolute upper-left Y:/ { y=$NF }
        /^  Width:/ { w=$NF }
        /^  Height:/ { h=$NF }
        END {
          if (w + 0 > 0 && h + 0 > 0) {
            print (w + 0) "x" (h + 0) "+" (x + 0) "+" (y + 0)
          } else {
            exit 1
          }
        }
      '
    }

    read_active_geometry() {
      active_window="$(${pkgs.xdotool}/bin/xdotool getactivewindow 2>/dev/null || true)"
      case "$active_window" in
        ""|*[!0-9]*)
          return 1
          ;;
      esac

      read_xwininfo_geometry -id "$active_window"
    }

    read_effective_geometry() {
      read_active_geometry \
        || read_xwininfo_geometry -root \
        || echo unknown
    }

    restart_polybar_after_randr_settles() {
      while true; do
        while true; do
          seen="$(${pkgs.coreutils}/bin/cat "$debounce_stamp" 2>/dev/null || true)"
          ${pkgs.coreutils}/bin/sleep 0.18
          latest="$(${pkgs.coreutils}/bin/cat "$debounce_stamp" 2>/dev/null || true)"
          [ -n "$seen" ] && [ "$seen" = "$latest" ] && break
        done
        settled_stamp="$latest"

        geometry="$(read_effective_geometry)"
        previous_geometry="$(${pkgs.coreutils}/bin/cat "$geometry_state" 2>/dev/null || true)"
        if [ "$geometry" = "$previous_geometry" ] && [ "$(polybar_count)" -ge 2 ]; then
          echo "ripper-polybar-resize-watch: RandR settled; geometry unchanged: $geometry"
        else
          echo "$geometry" > "$geometry_state"
          echo "ripper-polybar-resize-watch: RandR settled geometry=$geometry; polybar-msg cmd restart"
          if ${polybarPackage}/bin/polybar-msg cmd restart >/dev/null 2>&1 && ensure_two_polybars; then
            echo "ripper-polybar-resize-watch: polybar IPC restart sent"
          else
            echo "ripper-polybar-resize-watch: polybar IPC restart left an incomplete state; hard restarting both bars"
            "$HOME/.local/bin/ripper-polybar-start" --hard
          fi
        fi

        latest="$(${pkgs.coreutils}/bin/cat "$debounce_stamp" 2>/dev/null || true)"
        [ "$latest" = "$settled_stamp" ] && break
        echo "ripper-polybar-resize-watch: RandR changed during handling; waiting again"
      done

      ${pkgs.coreutils}/bin/rmdir "$debounce_lock" 2>/dev/null || true
    }

    schedule_polybar_randr_restart() {
      ${pkgs.coreutils}/bin/date +%s%N > "$debounce_stamp"
      if ${pkgs.coreutils}/bin/mkdir "$debounce_lock" 2>/dev/null; then
        restart_polybar_after_randr_settles &
      fi
    }

    while true; do
      ${pkgs.coreutils}/bin/stdbuf -oL -eL ${pkgs.xev}/bin/xev -root -event randr 2>&1 | while IFS= read -r event; do
        case "$event" in
          *RRScreenChangeNotify*|*RRNotify*)
            schedule_polybar_randr_restart
            ;;
        esac
      done
      echo "ripper-polybar-resize-watch: xev RandR watcher ended; retrying"
      ${pkgs.coreutils}/bin/sleep 0.25
      "$HOME/.local/bin/ripper-polybar-start"
    done
  '';
in
{
  home.activation.refresh-polybar-runtime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    if [ -n "$user_name" ]; then
      ${pkgs.procps}/bin/pkill -u "$user_name" -x polybar-reload 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -f ripper-polybar-resize-watch 2>/dev/null || true
    fi

    if [ -n "''${DISPLAY:-}" ] && [ -x "$HOME/.local/bin/ripper-polybar-resize-watch" ]; then
      "$HOME/.local/bin/ripper-polybar-resize-watch" >/dev/null 2>&1 &
    fi
  '';

  home.packages = [
    polybarPackage
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

  home.file.".local/bin/ripper-polybar-start" = {
    text = polybarStartScript;
    executable = true;
  };

  home.file.".local/bin/ripper-polybar-resize-watch" = {
    text = polybarResizeWatchScript;
    executable = true;
  };
}
