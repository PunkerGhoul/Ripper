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
    precision highp float;

    float hash(vec2 p) {
        p = fract(p * vec2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);

        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));

        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    float fbm3(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
        for (int i = 0; i < 3; i++) {
            v += a * noise(p);
            p = rot * p * 2.05 + 17.3;
            a *= 0.5;
        }
        return v;
    }

    float fbm5(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
        for (int i = 0; i < 5; i++) {
            v += a * noise(p);
            p = rot * p * 2.05 + 17.3;
            a *= 0.5;
        }
        return v;
    }

    void mainImage(out vec4 fragColor, in vec2 fragCoord) {
        vec2 designResolution = vec2(800.0, 450.0);
        float scale = iResolution.y / designResolution.y;
        vec2 uv = (fragCoord - 0.5 * iResolution.xy) / scale + 0.5 * designResolution;
        uv /= designResolution;

        float t = iTime * 0.16;
        uv.x += sin(iTime * 0.5 + uv.y * 10.0) * 0.05;
        uv.y += cos(iTime * 0.5 + uv.x * 10.0) * 0.05;

        vec2 mouse = (iMouse.xy / max(iResolution.xy, vec2(1.0)) - 0.5);
        float mouseDist = length(mouse);
        // Influencia reducida: el mouse modula parcialmente, pero la animación base sigue siendo dominante.
        float mouseInfluence = clamp(mouseDist * 2.0, 0.0, 1.0);
        float mouseActivity = pow(mouseInfluence, 0.7);

        vec2 p = (uv - 0.5) * vec2(designResolution.x / designResolution.y, 1.0);
        // Deform parcialmente siguiendo el mouse: efecto más sutil y suavizado
        p += mouse * 0.06 * mouseActivity;
        p *= 3.15;

        // Elegir detalle en función de la actividad del mouse:
        vec2 qLow = vec2(fbm3(p + vec2(0.0, t)), fbm3(p + vec2(5.2, 1.3 - t)));
        vec2 qHigh = vec2(fbm5(p + vec2(0.0, t)), fbm5(p + vec2(5.2, 1.3 - t)));
        vec2 q = mix(qLow, qHigh, mouseActivity);

        vec2 rLow = vec2(fbm3(p + 4.0 * q + vec2(1.7, 9.2)), fbm3(p + 4.0 * q + vec2(8.3, 2.8)));
        vec2 rHigh = vec2(fbm5(p + 4.0 * q + vec2(1.7, 9.2)), fbm5(p + 4.0 * q + vec2(8.3, 2.8)));
        vec2 r = mix(rLow, rHigh, mouseActivity);

        float n = mix(fbm3(p + 3.6 * q + vec2(0.0)), fbm5(p + 4.8 * r), mouseActivity);

        float veins = 1.0 - smoothstep(0.055, 0.18, abs(sin((n + r.x * 0.55) * 35.0)));
        float ridges = 1.0 - smoothstep(0.08, 0.23, abs(sin((n + q.y * 0.35) * 18.0)));
        float fine = 1.0 - smoothstep(0.012, 0.06, abs(sin((n + q.x) * 82.0)));

        vec3 col = vec3(0.005, 0.006, 0.010);
        col += vec3(0.28, 0.30, 0.32) * ridges;
        col += vec3(0.17, 0.18, 0.19) * veins;
        col += vec3(0.02, 0.03, 0.55) * fine * (0.35 + 0.65 * noise(p * 7.0));
        col += vec3(0.36, 0.34, 0.02) * fine * veins * 0.32;

        col *= 0.72 + 0.28 * smoothstep(0.15, 0.95, n);
        col = max(col - 0.015, 0.0);

        fragColor = vec4(col, 1.0);
    }
  '';
  sanitizeNeowallGlsl = glsl:
    let
      withoutLeadingNewline = lib.removePrefix "\n" glsl;
      lines = lib.splitString "\n" withoutLeadingNewline;
      withoutVersion =
        if lines != [] && lib.hasPrefix "#version" (builtins.head lines) then
          lib.concatStringsSep "\n" (builtins.tail lines)
        else
          withoutLeadingNewline;
      withoutUniforms = builtins.replaceStrings
        [
          "    uniform float iTime;\n"
          "        uniform float iTime;\n"
          "    uniform vec2 iResolution;\n"
          "        uniform vec2 iResolution;\n"
        ]
        [ "" "" "" "" ]
        withoutVersion;
    in
      builtins.replaceStrings
        [
          "void main()"
          "gl_FragCoord.xy"
          "gl_FragColor"
        ]
        [
          "void mainImage(out vec4 fragColor, in vec2 fragCoord)"
          "fragCoord"
          "fragColor"
        ]
        withoutUniforms;
  neowallGlsl = sanitizeNeowallGlsl (
    if (neowall ? glsl) && neowall.glsl != "" then
      neowall.glsl
    else if (neowall ? shaderCode) && neowall.shaderCode != "" then
      neowall.shaderCode
    else
      defaultNeowallGlsl
    );
  neowallConfig = neowall.config or ''
    default {
      shader ${neowallShaderName}
      shader_speed ${toString (neowall.speed or 1.0)}
      shader_fps ${toString (neowall.fps or 30)}
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
