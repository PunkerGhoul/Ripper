{ config, pkgs, unstable, lib, env, nixGLCommand, ... }:

let
  logoutScript = pkgs.writeShellScript "ripper-logout" ''
    runtime_dir="''${XDG_RUNTIME_DIR:-}"
    session_pid=
    if [ -n "$runtime_dir" ] && [ -r "$runtime_dir/ripper-session.pid" ]; then
      IFS= read -r session_pid < "$runtime_dir/ripper-session.pid" || session_pid=
    fi

    ${pkgs.i3}/bin/i3-msg exit >/dev/null 2>&1 || true

    case "$session_pid" in
      ""|*[!0-9]*) exit 0 ;;
    esac

    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$session_pid" >/dev/null 2>&1 || exit 0
      ${pkgs.coreutils}/bin/sleep 0.05
    done

    kill -TERM "$session_pid" >/dev/null 2>&1 || exit 0

    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$session_pid" >/dev/null 2>&1 || exit 0
      ${pkgs.coreutils}/bin/sleep 0.05
    done

    kill -KILL "$session_pid" >/dev/null 2>&1 || true
    exit 0
  '';
in
{
  imports = [
    (import ./x { inherit config pkgs lib logoutScript; })
    (import ./programs { inherit config pkgs lib unstable env nixGLCommand; })
    (import ./services { inherit config pkgs logoutScript; })
  ];
}
