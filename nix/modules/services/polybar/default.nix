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
  polybarStartScript = ''
    #!${pkgs.runtimeShell}
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-polybar.log"
    config="$HOME/.config/polybar/${theme}/config.ini"

    {
      echo "ripper-polybar-start: $(${pkgs.coreutils}/bin/date)"

      if [ -z "''${DISPLAY:-}" ]; then
        echo "DISPLAY is not set"
        exit 0
      fi

      exec 9>"$runtime_dir/ripper-polybar-start.lock"
      if ! ${pkgs.util-linux}/bin/flock -n 9; then
        echo "polybar start already running"
        exit 0
      fi

      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        [ -r "$config" ] && break
        ${pkgs.coreutils}/bin/sleep 0.05
      done
      if [ ! -r "$config" ]; then
        echo "missing config: $config"
        exit 0
      fi

      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        ${pkgs.i3}/bin/i3-msg -t get_workspaces >/dev/null 2>&1 && break
        ${pkgs.coreutils}/bin/sleep 0.05
      done

      for _ in 1 2 3 4 5; do
        ${pkgs.psmisc}/bin/killall -q polybar 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          ${pkgs.procps}/bin/pgrep -u "$UID" -x polybar >/dev/null 2>&1 || break
          ${pkgs.coreutils}/bin/sleep 0.05
        done

        ${polybarPackage}/bin/polybar -q top -c "$config" &
        ${polybarPackage}/bin/polybar -q bottom -c "$config" &

        ${pkgs.coreutils}/bin/sleep 0.2
        running="$(${pkgs.procps}/bin/pgrep -u "$UID" -x polybar 2>/dev/null | ${pkgs.coreutils}/bin/wc -l | ${pkgs.coreutils}/bin/tr -d ' ' || true)"
        if [ "''${running:-0}" -ge 2 ]; then
          echo "polybar started: $running processes"
          exit 0
        fi

        echo "polybar did not stay up; retrying"
      done
    } > "$log" 2>&1
  '';
  polybarResizeWatchScript = ''
    #!${pkgs.runtimeShell}
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-polybar-resize.log"
    exec >>"$log" 2>&1

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    exec 9>"$runtime_dir/ripper-polybar-resize.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "ripper-polybar-resize-watch: already running"
      exit 0
    fi

    echo "ripper-polybar-resize-watch: start $(${pkgs.coreutils}/bin/date) DISPLAY=''${DISPLAY:-unset}"
    exec ${polybarReload}/bin/polybar-reload "$HOME/.local/bin/ripper-polybar-start"
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
    text = polybarStartScript;
    executable = true;
  };

  home.file.".local/bin/ripper-polybar-resize-watch" = {
    text = polybarResizeWatchScript;
    executable = true;
  };
}
