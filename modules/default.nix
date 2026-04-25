{ config, pkgs, unstable, lib, env, nixGLCommand, ... }:

let
  logoutScript = pkgs.writeShellScript "ripper-logout" ''
    if [ -n "''${XDG_SESSION_ID:-}" ] && [ -x /usr/bin/loginctl ]; then
      /usr/bin/loginctl terminate-session "$XDG_SESSION_ID" >/dev/null 2>&1 && exit 0
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
