{ config, pkgs, unstable, nixosPkgs, lib, env, installConfig, nixGLCommand, ... }:

let
  logoutScript = pkgs.writeShellScript "ripper-logout" ''
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    ${pkgs.coreutils}/bin/mkdir -p "$runtime_dir" 2>/dev/null || true
    ${pkgs.coreutils}/bin/chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-logout.log"
    : > "$log"
    exec >> "$log" 2>&1

    echo "ripper-logout: start $(${pkgs.coreutils}/bin/date)"
    echo "ripper-logout: USER=''${USER:-unset} UID=''${UID:-unset} XDG_SESSION_ID=''${XDG_SESSION_ID:-unset} DISPLAY=''${DISPLAY:-unset} I3SOCK=''${I3SOCK:-unset}"

    ${pkgs.psmisc}/bin/killall -q polybar 2>/dev/null || true

    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    session_id="''${XDG_SESSION_ID:-}"

    i3_alive() {
      [ -n "$user_name" ] && ${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 >/dev/null 2>&1
    }

    session_alive() {
      [ -n "$session_id" ] && [ -n "$loginctl_bin" ] && "$loginctl_bin" show-session "$session_id" >/dev/null 2>&1
    }

    logout_done() {
      if [ -n "$session_id" ] && [ -n "$loginctl_bin" ]; then
        ! session_alive
        return
      fi

      ! i3_alive
    }

    wait_for_logout_done() {
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        logout_done && return 0
        ${pkgs.coreutils}/bin/sleep 0.05
      done

      return 1
    }

    try_i3_msg_exit() {
      echo "ripper-logout: trying i3-msg exit"
      ${pkgs.i3}/bin/i3-msg exit || true
      wait_for_logout_done
    }

    try_loginctl_terminate_session() {
      [ -n "$session_id" ] || return 1
      [ -n "$loginctl_bin" ] || return 1

      echo "ripper-logout: trying loginctl terminate-session $session_id"
      "$loginctl_bin" terminate-session "$session_id" || true
      wait_for_logout_done
    }

    try_loginctl_kill_session() {
      [ -n "$session_id" ] || return 1
      [ -n "$loginctl_bin" ] || return 1

      echo "ripper-logout: trying loginctl kill-session $session_id"
      "$loginctl_bin" kill-session "$session_id" || true
      wait_for_logout_done
    }

    try_kill_i3() {
      [ -n "$user_name" ] || return 1

      echo "ripper-logout: trying pkill TERM i3"
      ${pkgs.procps}/bin/pkill -TERM -u "$user_name" -x i3 2>/dev/null || true
      wait_for_logout_done && return 0

      echo "ripper-logout: trying pkill KILL i3"
      ${pkgs.procps}/bin/pkill -KILL -u "$user_name" -x i3 2>/dev/null || true
      wait_for_logout_done
    }

    if [ -n "$user_name" ]; then
      ${pkgs.procps}/bin/pkill -u "$user_name" -x picom 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -f ripper-vmware-auto-resize 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -f ripper-wallpaper-start 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -f ripper-wallpaper-resize-watch 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x ripper-wallpaper-watch 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x neowall 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -f 'vmtoolsd -n vmusr' 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x vmware-user-suid-wrapper 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x vmware-user 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x polybar-reload 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -f ripper-polybar-resize-watch 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x dunst 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x nm-applet 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x flameshot 2>/dev/null || true
    fi

    loginctl_bin=
    for candidate in /usr/bin/loginctl /bin/loginctl ${pkgs.systemd}/bin/loginctl; do
      if [ -x "$candidate" ]; then
        loginctl_bin="$candidate"
        break
      fi
    done

    if [ -n "$session_id" ] && [ -n "$loginctl_bin" ]; then
      "$loginctl_bin" session-status "$session_id" || true
    fi

    if logout_done; then
      echo "ripper-logout: session is already closed"
      exit 0
    fi

    if try_i3_msg_exit; then
      echo "ripper-logout: i3 exited through i3-msg"
      exit 0
    fi

    if try_loginctl_terminate_session; then
      echo "ripper-logout: i3 exited through loginctl terminate-session"
      exit 0
    fi

    if try_loginctl_kill_session; then
      echo "ripper-logout: i3 exited through loginctl kill-session"
      exit 0
    fi

    if try_kill_i3; then
      echo "ripper-logout: i3 exited through pkill"
      exit 0
    fi

    echo "ripper-logout: failed; session is still active"
    exit 1
  '';
in
{
  imports = [
    (import ./x { inherit config pkgs lib installConfig nixGLCommand logoutScript; })
    (import ./xdg { inherit config pkgs lib; })
    (import ./programs { inherit config pkgs lib unstable nixosPkgs env nixGLCommand; })
    (import ./services { inherit config pkgs lib nixGLCommand logoutScript; })
  ];
}
