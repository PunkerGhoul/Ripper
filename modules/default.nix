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
