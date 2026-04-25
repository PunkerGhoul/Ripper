{ config, pkgs, logoutScript ? null, ... }:

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
  polybarReload = import ./polybar-reload   { inherit pkgs polybarPackage; };
  resolvedLogoutScript =
    if logoutScript != null then
      logoutScript
    else
      pkgs.writeShellScript "ripper-logout-fallback" ''
        ${pkgs.i3}/bin/i3-msg exit >/dev/null 2>&1 || true
      '';
  polybarTheme  = import ./polybar-themes   { inherit pkgs theme polybarPackage; logoutScript = resolvedLogoutScript; };
  polybarStart = pkgs.writeShellScript "ripper-polybar-start" ''
    config="$HOME/.config/polybar/${theme}/config.ini"
    [ -r "$config" ] || exit 0

    ${pkgs.psmisc}/bin/killall -q polybar 2>/dev/null || true
    ${polybarPackage}/bin/polybar -q top -c "$config" &
    ${polybarPackage}/bin/polybar -q bottom -c "$config" &
  '';
in
{
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
    source = polybarStart;
    executable = true;
  };
}
