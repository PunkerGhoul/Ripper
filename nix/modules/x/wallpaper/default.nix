{ config, pkgs, lib, installConfig ? { }, nixGLCommand, ... }:

let
  nixGL = import ../../nixgl { inherit pkgs nixGLCommand; };
  neowallPackage = nixGL pkgs.neowall;

  wallpaper = installConfig.wallpaper or { };
  feh = wallpaper.feh or { };
  neowall = wallpaper.neowall or { };

  fehEnable = feh.enable or true;
  neowallEnable = neowall.enable or true;

  sourceToString = source:
    if builtins.isPath source then
      toString source
    else if builtins.isString source then
      source
    else
      throw "wallpaper.feh.source/path/url must be a path or string";

  configuredFehSource =
    if feh ? url then
      feh.url
    else if feh ? source then
      feh.source
    else if feh ? path then
      feh.path
    else
      "$HOME/Pictures/Wallpapers/cyberpunk.jpg";

  rawFehSource = sourceToString configuredFehSource;
  fehSourceIsUrl =
    lib.hasPrefix "https://" rawFehSource
    || lib.hasPrefix "http://" rawFehSource;
  fehHash = feh.hash or feh.sha256 or "";
  fehFetchHash =
    if fehHash != "" then
      fehHash
    else
      throw "wallpaper.feh.hash or wallpaper.feh.sha256 is required when wallpaper.feh.source/url is an URL";
  fehFetchArgs = { url = rawFehSource; } // (
    if lib.hasPrefix "sha256-" fehFetchHash then
      { hash = fehFetchHash; }
    else
      { sha256 = fehFetchHash; }
  );
  fehSource =
    if fehEnable && fehSourceIsUrl then
      toString (pkgs.fetchurl fehFetchArgs)
    else
      rawFehSource;

  fehModes = {
    center = "--bg-center";
    fill = "--bg-fill";
    max = "--bg-max";
    scale = "--bg-scale";
    tile = "--bg-tile";
  };
  fehMode = feh.mode or "center";
  fehFlag = fehModes.${fehMode} or (throw "Unsupported wallpaper.feh.mode: ${fehMode}");

  neowallShaderName = neowall.shaderName or neowall.shader or "ripper.glsl";
  neowallGlsl = neowall.glsl or neowall.shaderCode or ''
    #version 100
    precision highp float;

    uniform float iTime;
    uniform vec2 iResolution;

    void main() {
        vec2 uv = gl_FragCoord.xy / iResolution.xy;
        uv.x *= iResolution.x / iResolution.y;

        float waveScale = 2.4;
        vec2 wideUv = uv / waveScale;
        vec3 color = 0.5 + 0.5 * cos(iTime + wideUv.xyx + vec3(0.0, 2.0, 4.0));
        gl_FragColor = vec4(color, 1.0);
    }
  '';
  neowallConfig = neowall.config or ''
    default {
      shader ${neowallShaderName}
      shader_speed ${toString (neowall.speed or 1.0)}
      shader_fps ${toString (neowall.fps or 24)}
      vsync ${lib.boolToString (neowall.vsync or true)}
      show_fps ${lib.boolToString (neowall.showFps or false)}
    }
  '';

  wallpaperStartScript = ''
    #!${pkgs.runtimeShell}
    set -u

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir" 2>/dev/null || true
    log="$runtime_dir/ripper-wallpaper.log"
    exec >>"$log" 2>&1

    if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    expand_wallpaper_path() {
      case "$1" in
        "~/"*)
          printf '%s\n' "$HOME/''${1#"~/"}"
          ;;
        "\$HOME/"*)
          printf '%s\n' "$HOME/''${1#"\$HOME/"}"
          ;;
        *)
          printf '%s\n' "$1"
          ;;
      esac
    }

    apply_feh_wallpaper() {
      [ "${lib.boolToString fehEnable}" = "true" ] || return 1

      source="$(expand_wallpaper_path ${lib.escapeShellArg fehSource})"
      if [ ! -e "$source" ]; then
        echo "ripper-wallpaper: feh source does not exist: $source"
        return 1
      fi

      echo "ripper-wallpaper: applying feh wallpaper: $source"
      ${pkgs.feh}/bin/feh ${fehFlag} "$source"
    }

    start_neowall() {
      [ "${lib.boolToString neowallEnable}" = "true" ] || return 1

      exec 8>"$runtime_dir/ripper-neowall.lock"
      if ! ${pkgs.util-linux}/bin/flock -n 8; then
        echo "ripper-wallpaper: neowall launcher already running"
        return 0
      fi

      user_id="$(${pkgs.coreutils}/bin/id -u)"
      neowall_running() {
        ${pkgs.procps}/bin/pgrep -u "$user_id" -f '/bin/neowall([ ]|$)' >/dev/null 2>&1 \
          || ${pkgs.procps}/bin/pgrep -u "$user_id" -x neowall >/dev/null 2>&1
      }

      if neowall_running; then
        echo "ripper-wallpaper: neowall is already running"
        return 0
      fi

      if [ "${lib.boolToString (neowall.killBeforeStart or false)}" = "true" ]; then
        ${neowallPackage}/bin/neowall kill >/dev/null 2>&1 || true
      fi

      echo "ripper-wallpaper: starting neowall"
      ${pkgs.util-linux}/bin/setsid -f \
        ${pkgs.coreutils}/bin/nice -n ${toString (neowall.nice or 10)} \
        ${neowallPackage}/bin/neowall
      ${pkgs.coreutils}/bin/sleep 1

      if neowall_running; then
        echo "ripper-wallpaper: neowall started"
        return 0
      fi

      echo "ripper-wallpaper: neowall did not stay running"
      return 1
    }

    if start_neowall; then
      exit 0
    fi

    apply_feh_wallpaper || true
  '';
in
{
  home.packages =
    lib.optionals fehEnable [ pkgs.feh ]
    ++ lib.optionals neowallEnable [ neowallPackage ];

  home.file =
    {
      ".local/bin/ripper-wallpaper-start" = {
        text = wallpaperStartScript;
        executable = true;
      };
    }
    // lib.optionalAttrs neowallEnable {
      ".config/neowall/config.vibe".text = neowallConfig;
      ".config/neowall/shaders/${neowallShaderName}".text = neowallGlsl;
    };
}
