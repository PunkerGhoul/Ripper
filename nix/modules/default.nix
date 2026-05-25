{ config, pkgs, unstable, nixosPkgs, lib, env, installConfig, nixGLCommand, ... }:

let
  logoutScriptBase = pkgs.writeShellScript "ripper-logout" ''
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    ${pkgs.coreutils}/bin/mkdir -p "$runtime_dir" 2>/dev/null || true
    ${pkgs.coreutils}/bin/chmod 700 "$runtime_dir" 2>/dev/null || true
    if [ -n "''${HOME:-}" ]; then
      log_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/ripper"
      ${pkgs.coreutils}/bin/mkdir -p "$log_dir" 2>/dev/null || true
      log="$log_dir/logout.log"
    else
      log="$runtime_dir/ripper-logout.log"
    fi
    : > "$log"
    exec >> "$log" 2>&1

    echo "ripper-logout: start $(${pkgs.coreutils}/bin/date)"
    echo "ripper-logout: USER=''${USER:-unset} UID=''${UID:-unset} XDG_SESSION_ID=''${XDG_SESSION_ID:-unset} DISPLAY=''${DISPLAY:-unset} I3SOCK=''${I3SOCK:-unset}"

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi

    if [ -z "''${XAUTHORITY:-}" ] && [ -n "''${HOME:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"

    if [ -z "$user_name" ]; then
      echo "ripper-logout: USER is not set and id -un failed"
      exit 1
    fi

    loginctl_bin=
    for candidate in /usr/bin/loginctl /bin/loginctl ${pkgs.systemd}/bin/loginctl; do
      if [ -x "$candidate" ]; then
        loginctl_bin="$candidate"
        break
      fi
    done

    systemctl_bin=
    for candidate in /usr/bin/systemctl /bin/systemctl ${pkgs.systemd}/bin/systemctl; do
      if [ -x "$candidate" ]; then
        systemctl_bin="$candidate"
        break
      fi
    done

    i3_sock=""
    i3_socket_arg=""
    i3_pid="$(${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 2>/dev/null | ${pkgs.coreutils}/bin/head -n 1 || true)"
    if [ -n "$i3_pid" ] && [ -r "/proc/$i3_pid/environ" ]; then
      i3_env="$(${pkgs.coreutils}/bin/tr '\0' '\n' < "/proc/$i3_pid/environ")"
      i3_sock_env="$(printf '%s\n' "$i3_env" | ${pkgs.gnugrep}/bin/grep -m1 '^I3SOCK=' | ${pkgs.coreutils}/bin/cut -d= -f2-)"
      display_env="$(printf '%s\n' "$i3_env" | ${pkgs.gnugrep}/bin/grep -m1 '^DISPLAY=' | ${pkgs.coreutils}/bin/cut -d= -f2-)"
      xauth_env="$(printf '%s\n' "$i3_env" | ${pkgs.gnugrep}/bin/grep -m1 '^XAUTHORITY=' | ${pkgs.coreutils}/bin/cut -d= -f2-)"
      if [ -z "''${DISPLAY:-}" ] && [ -n "$display_env" ]; then
        export DISPLAY="$display_env"
      fi
      if [ -z "''${XAUTHORITY:-}" ] && [ -n "$xauth_env" ]; then
        export XAUTHORITY="$xauth_env"
      fi
      if [ -n "$i3_sock_env" ] && [ -S "$i3_sock_env" ]; then
        i3_sock="$i3_sock_env"
      fi
    fi

    socket_candidates=""
    if [ -z "$i3_sock" ] || [ ! -S "$i3_sock" ]; then
      i3_sock="$(I3SOCK= ${pkgs.i3}/bin/i3 --get-socketpath 2>/dev/null || true)"
    fi
    if [ -n "$i3_sock" ] && [ -S "$i3_sock" ]; then
      socket_candidates="$i3_sock"
    fi
    for sock in $(${pkgs.coreutils}/bin/ls -t "/run/user/$UID/i3/ipc-socket."* 2>/dev/null || true); do
      case " $socket_candidates " in
        *" $sock "*)
          ;;
        *)
          socket_candidates="$socket_candidates $sock"
          ;;
      esac
    done

    for sock in $socket_candidates; do
      if [ -S "$sock" ] && I3SOCK= ${pkgs.i3}/bin/i3-msg -s "$sock" -t get_version >/dev/null 2>&1; then
        i3_sock="$sock"
        break
      fi
    done

    if [ -n "$i3_sock" ] && [ -S "$i3_sock" ]; then
      export I3SOCK="$i3_sock"
      i3_socket_arg="-s $i3_sock"
    fi
    echo "ripper-logout: i3_sock=''${i3_sock:-unset}"

    try_i3_exit() {
      local args="$1"
      local output
      output="$(I3SOCK= ${pkgs.i3}/bin/i3-msg $args exit 2>&1)" && return 0
      echo "ripper-logout: i3-msg exit failed ($args): $output"
      return 1
    }

    terminate_session_wrapper() {
      if [ -z "$user_name" ]; then
        return 0
      fi
      if [ -n "$i3_pid" ] && [ -r "/proc/$i3_pid/stat" ]; then
        i3_ppid="$(${pkgs.coreutils}/bin/awk '{print $4}' "/proc/$i3_pid/stat" 2>/dev/null || true)"
        if [ -n "$i3_ppid" ] && [ "$i3_ppid" != "1" ]; then
          parent_comm="$(${pkgs.procps}/bin/ps -o comm= -p "$i3_ppid" 2>/dev/null || true)"
          echo "ripper-logout: i3 parent pid=$i3_ppid comm=$parent_comm"
          case "$parent_comm" in
            dbus-launch|ripper-session|ripper-session-start|sh|bash)
              echo "ripper-logout: kill parent $i3_ppid ($parent_comm)"
              ${pkgs.coreutils}/bin/kill -TERM "$i3_ppid" 2>/dev/null || true
              ${pkgs.coreutils}/bin/sleep 0.1
              ${pkgs.coreutils}/bin/kill -KILL "$i3_ppid" 2>/dev/null || true
              ;;
          esac
        fi
      fi
      echo "ripper-logout: pkill -TERM -x ripper-session"
      ${pkgs.procps}/bin/pkill -TERM -u "$user_name" -x ripper-session >/dev/null 2>&1 || true
      echo "ripper-logout: pkill -TERM -x ripper-session-start"
      ${pkgs.procps}/bin/pkill -TERM -u "$user_name" -x ripper-session-start >/dev/null 2>&1 || true
      echo "ripper-logout: pkill -TERM -x dbus-launch"
      ${pkgs.procps}/bin/pkill -TERM -u "$user_name" -x dbus-launch >/dev/null 2>&1 || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        ${pkgs.procps}/bin/pgrep -u "$user_name" -x dbus-launch >/dev/null 2>&1 || return 0
        ${pkgs.coreutils}/bin/sleep 0.1
      done
      echo "ripper-logout: pkill -KILL -x dbus-launch"
      ${pkgs.procps}/bin/pkill -KILL -u "$user_name" -x dbus-launch >/dev/null 2>&1 || true
    }

    force_user_exit() {
      if [ -n "''${systemctl_bin:-}" ]; then
        echo "ripper-logout: systemctl --user exit"
        "$systemctl_bin" --user exit >/dev/null 2>&1 || true
        return 0
      fi
      if [ -n "''${XDG_SESSION_ID:-}" ] && [ -n "''${loginctl_bin:-}" ]; then
        echo "ripper-logout: loginctl kill-session ''${XDG_SESSION_ID}"
        "$loginctl_bin" kill-session "''${XDG_SESSION_ID}" >/dev/null 2>&1 || true
      fi
    }

    if ${pkgs.i3}/bin/i3-msg $i3_socket_arg -t get_version >/dev/null 2>&1; then
      echo "ripper-logout: i3-msg exit"
      if try_i3_exit "$i3_socket_arg"; then
        exit 0
      fi
      if [ -n "$i3_socket_arg" ] && try_i3_exit ""; then
        exit 0
      fi
      if [ -n "$user_name" ] && ! ${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 >/dev/null 2>&1; then
        echo "ripper-logout: i3 already exited"
        terminate_session_wrapper
        force_user_exit
        exit 0
      fi
    fi

    if [ -n "$user_name" ]; then
      echo "ripper-logout: pkill -KILL -x i3"
      ${pkgs.procps}/bin/pkill -KILL -u "$user_name" -x i3 >/dev/null 2>&1 || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        ${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 >/dev/null 2>&1 || exit 0
        ${pkgs.coreutils}/bin/sleep 0.1
      done
      ${pkgs.procps}/bin/pgrep -a -u "$user_name" -x i3 >/dev/null 2>&1 || true
      terminate_session_wrapper
      force_user_exit
    fi

    echo "ripper-logout: unable to terminate i3 cleanly"
    exit 1
  '';
  confirmLogoutScript = pkgs.writeShellScript "ripper-confirm-logout" ''
    exec ${pkgs.i3}/bin/i3-nagbar \
      -t warning \
      -m "Exit this i3 session and return to SDDM?" \
      -B "Yes, logout" "${logoutScriptBase}"
  '';
in
{
  imports = [
    (import ./x { inherit config pkgs lib installConfig nixGLCommand confirmLogoutScript; })
    (import ./xdg { inherit config pkgs lib; })
    (import ./programs { inherit config pkgs lib unstable nixosPkgs env nixGLCommand; })
    (import ./services { inherit config pkgs lib nixGLCommand; logoutScript = logoutScriptBase; })
    (import ./sddm { inherit config pkgs lib installConfig; })
  ];
}
