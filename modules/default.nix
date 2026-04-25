{ config, pkgs, unstable, lib, env, nixGLCommand, ... }:

let
  logoutScript = pkgs.writeShellScript "ripper-logout" ''
    ${pkgs.psmisc}/bin/killall -q polybar 2>/dev/null || true

    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    if [ -n "$user_name" ]; then
      ${pkgs.procps}/bin/pkill -u "$user_name" -x picom 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x polybar-reload 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x dunst 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x nm-applet 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -u "$user_name" -x flameshot 2>/dev/null || true
    fi

    ${pkgs.i3}/bin/i3-msg exit >/dev/null 2>&1 || true

    if [ -n "$user_name" ]; then
      for _ in 1 2 3 4 5 6 7 8; do
        ${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 >/dev/null 2>&1 || exit 0
        ${pkgs.coreutils}/bin/sleep 0.025
      done

      ${pkgs.procps}/bin/pkill -TERM -u "$user_name" -x i3 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8; do
        ${pkgs.procps}/bin/pgrep -u "$user_name" -x i3 >/dev/null 2>&1 || exit 0
        ${pkgs.coreutils}/bin/sleep 0.025
      done

      ${pkgs.procps}/bin/pkill -KILL -u "$user_name" -x i3 2>/dev/null || true
    fi
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
