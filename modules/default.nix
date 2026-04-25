{ config, pkgs, unstable, lib, env, nixGLCommand, ... }:

let
  logoutScript = pkgs.writeShellScript "ripper-logout" ''
    runtime_dir="''${XDG_RUNTIME_DIR:-}"
    if [ -n "$runtime_dir" ] && [ -r "$runtime_dir/ripper-session.pid" ]; then
      IFS= read -r session_pid < "$runtime_dir/ripper-session.pid" || session_pid=
      case "$session_pid" in
        ""|*[!0-9]*) ;;
        *)
          kill -TERM "$session_pid" >/dev/null 2>&1 && exit 0
          ;;
      esac
    fi

    ${pkgs.i3}/bin/i3-msg exit >/dev/null 2>&1 && exit 0

    exit 1
  '';
in
{
  imports = [
    (import ./x { inherit config pkgs lib logoutScript; })
    (import ./programs { inherit config pkgs lib unstable env nixGLCommand; })
    (import ./services { inherit config pkgs logoutScript; })
  ];
}
