{ config, pkgs, lib, installConfig ? { }, nixGLCommand, ... }:

let
  nixGL = import ../../nixgl { inherit pkgs nixGLCommand; };
  neowallPackage = nixGL pkgs.neowall;

  wallpaper = installConfig.wallpaper or { };
  feh = wallpaper.feh or { };
  neowall = wallpaper.neowall or { };

  fehEnable = feh.enable or false;
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
  defaultNeowallGlsl = ''
    #version 100
    precision highp float;

    uniform float iTime;
    uniform vec2 iResolution;

    void main() {
        vec2 designResolution = vec2(800.0, 450.0);
        float scale = iResolution.y / designResolution.y;
        vec2 fragCoord = (gl_FragCoord.xy - 0.5 * iResolution.xy) / scale + 0.5 * designResolution;
        vec2 uv = fragCoord / designResolution;
        float t = iTime * 0.5;

        uv.x += sin(t + uv.y * 10.0) * 0.05;
        uv.y += cos(t + uv.x * 10.0) * 0.05;

        vec2 p = (uv - 0.5) * vec2(designResolution.x / designResolution.y, 1.0);
        float base = sin(p.x * 7.0 + t) + cos(p.y * 9.0 - t) + sin((p.x + p.y) * 6.0 + t * 0.7);
        float tex = sin(base + length(p) * 30.0) * 0.5 + 0.5;
        float blue = max((sin(tex * 30.0) * 0.5 + 0.5 - 0.30) * 1.4, 0.0);
        vec3 col = vec3(0.0, 0.02 * blue, blue);

        gl_FragColor = vec4(col, 1.0);
    }
  '';
  neowallGlsl =
    if (neowall ? glsl) && neowall.glsl != "" then
      neowall.glsl
    else if (neowall ? shaderCode) && neowall.shaderCode != "" then
      neowall.shaderCode
    else
      defaultNeowallGlsl;
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

      echo "ripper-wallpaper: starting neowall"
      ${neowallPackage}/bin/neowall kill >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/nice -n ${toString (neowall.nice or 10)} \
        ${neowallPackage}/bin/neowall &
      pid="$!"
      ${pkgs.coreutils}/bin/sleep 0.35

      if kill -0 "$pid" 2>/dev/null; then
        echo "ripper-wallpaper: neowall is running"
        return 0
      fi

      if wait "$pid"; then
        echo "ripper-wallpaper: neowall started"
        return 0
      fi

      status="$?"
      echo "ripper-wallpaper: neowall failed with status $status"
      return "$status"
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
