{ config, pkgs, unstable, nixosPkgs, lib, env, installConfig, nixGLCommand, ... }:

let
  logoutScript = pkgs.writeShellScript "ripper-logout" ''
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

    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    loginctl_bin=
    for candidate in /usr/bin/loginctl /bin/loginctl ${pkgs.systemd}/bin/loginctl; do
      if [ -x "$candidate" ]; then
        loginctl_bin="$candidate"
        break
      fi
    done

    if [ -z "$user_name" ]; then
      echo "ripper-logout: USER is not set and id -un failed"
      exit 1
    fi

    if [ -z "$loginctl_bin" ]; then
      echo "ripper-logout: loginctl not found"
      exit 1
    fi

    echo "ripper-logout: loginctl kill-user $user_name"
    exec "$loginctl_bin" kill-user "$user_name"
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
