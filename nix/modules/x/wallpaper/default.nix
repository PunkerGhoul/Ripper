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

      const float PI = 3.14159265359;
      const float SPEED = 1.0;
      const float STEP_COUNT = 8.0;

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

    float fbm(vec2 p) {
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

    vec2 rotate(vec2 v, float a) {
      float s = sin(a);
      float c = cos(a);
      return mat2(c, -s, s, c) * v;
    }

    float smoothstep1(float x) {
      return smoothstep(0.0, 1.0, x);
    }

    vec2 movement_path(float time, vec2 mouse, out float angle, out float turnWeight) {
      float turn_rad = 0.25 / 3.0;
      float turn_abs_time = (PI / 2.0 * turn_rad) * 1.5;
      float turn_time = turn_abs_time / (1.0 - 2.0 * turn_rad + turn_abs_time);
      float level1_size = 10.0 * 3.0 * 12.0 * 0.10;
      float level2_size = 4.0 * level1_size;

      float tq = fract(time / (level2_size * 4.0) * 12.0);
      float t8 = fract(tq * 4.0);
      float t1 = fract(t8 * 8.0);

      vec2 prev;
      vec2 dir;
      if (tq < 0.25) {
        prev = vec2(0.0, 0.0);
        dir = vec2(0.0, 1.0);
      } else if (tq < 0.5) {
        prev = vec2(0.0, 1.0);
        dir = vec2(1.0, 0.0);
      } else if (tq < 0.75) {
        prev = vec2(1.0, 1.0);
        dir = vec2(0.0, -1.0);
      } else {
        prev = vec2(1.0, 0.0);
        dir = vec2(-1.0, 0.0);
      }

      prev *= 4.0;
      vec2 dirL = rotate(dir, -PI / 2.0);
      vec2 dirR = -dirL;

      vec2 turn;
      float turn_sign = 0.0;
      float up_down = 0.0;
      float rotate_on_turns = 1.0;
      float roll_on_turns = 1.0;
      float add_angle = 0.0;

      if (t8 < 0.125) {
        turn = dirL;
        turn_sign = -1.0;
        angle = -0.4 * (max(0.0, t1 - (1.0 - turn_time * 2.0)) / turn_time - max(0.0, t1 - (1.0 - turn_time)) / turn_time * 2.5);
        roll_on_turns = 0.0;
      } else if (t8 < 0.250) {
        prev += dir;
        turn = dir;
        dir = dirL;
        angle = -1.0;
        turn_sign = 1.0;
        add_angle += 0.4 * 0.5 + (-0.4 * 0.5 + 1.0 + 0.5) * t1;
        rotate_on_turns = 0.0;
        roll_on_turns = 0.0;
      } else if (t8 < 0.375) {
        prev += dir + dirL;
        turn = dirR;
        turn_sign = 1.0;
        add_angle += 0.5 * sqrt(1.0 - t1);
      } else if (t8 < 0.5) {
        prev += dir + dir + dirL;
        turn = dirR;
        dir = dirR;
        angle = 1.0;
        turn_sign = 0.0;
        up_down = sin(t1 * PI) * 0.37;
      } else if (t8 < 0.625) {
        prev += dir + dir;
        turn = dir;
        dir = dirR;
        angle = 1.0;
        turn_sign = -1.0;
        up_down = sin(-min(1.0, t1 / (1.0 - turn_time)) * PI) * 0.37;
      } else if (t8 < 0.750) {
        prev += dir + dir + dirR;
        turn = dirL;
        turn_sign = -1.0;
        add_angle -= (0.25 + 1.0) * smoothstep1(t1);
        rotate_on_turns = 0.0;
        roll_on_turns = 0.0;
      } else if (t8 < 0.875) {
        prev += dir + dir + dir + dirR;
        turn = dir;
        dir = dirL;
        angle = -1.0;
        turn_sign = 1.0;
        add_angle -= 0.25 - smoothstep1(t1) * (0.25 * 2.0 + 1.0);
        rotate_on_turns = 0.0;
        roll_on_turns = 0.0;
      } else {
        prev += dir + dir + dir;
        turn = dirR;
        turn_sign = 1.0;
        angle = 0.25 * (1.5 * min(1.0, (1.0 - t1) / turn_time) - 0.5 * smoothstep1(1.0 - min(1.0, t1 / (1.0 - turn_time))));
      }

      if (length(mouse) > 0.01) {
        up_down = -0.7 * mouse.y;
        angle += mouse.x;
        rotate_on_turns = 1.0;
        roll_on_turns = 0.0;
      } else {
        angle += add_angle;
      }

      vec2 p;
      if (turn_sign == 0.0) {
        p = prev + dir * (turn_rad + 1.0 * t1);
      } else if (t1 > (1.0 - turn_time)) {
        float tr = (t1 - (1.0 - turn_time)) / turn_time;
        vec2 c = prev + dir * (1.0 - turn_rad) + turn * turn_rad;
        p = c + turn_rad * rotate(dir, (tr - 1.0) * turn_sign * PI / 2.0);
        angle += tr * turn_sign * rotate_on_turns;
      } else {
        t1 /= (1.0 - turn_time);
        p = prev + dir * (turn_rad + (1.0 - turn_rad * 2.0) * t1);
      }

      turnWeight = clamp(abs(mouse.x) + abs(mouse.y), 0.0, 1.0);
      p *= level1_size * 0.33;
      p += vec2(sin(time * 0.6), cos(time * 0.45)) * 0.8;
      p += rotate(vec2(mouse.x, mouse.y), angle) * 1.4;
      return p;
    }

    void mainImage(out vec4 fragColor, in vec2 fragCoord) {
      vec2 designResolution = vec2(800.0, 450.0);
      float scale = iResolution.y / designResolution.y;
      vec2 uv = (fragCoord - 0.5 * iResolution.xy) / scale + 0.5 * designResolution;
      uv /= designResolution;

      vec2 mouse = iMouse.xy / iResolution.xy * 2.0 - 1.0;
      float angle = 0.0;
      float turnWeight = 0.0;
      float time = iTime * SPEED;
      vec2 path = movement_path(time, mouse, angle, turnWeight);

      vec2 p = (uv - 0.5) * vec2(designResolution.x / designResolution.y, 1.0);
      p *= 3.15;
      p += path * 0.08;
      p += rotate(uv, angle) * 0.12;
      p += vec2(sin(time * 0.5), cos(time * 0.35)) * 0.04;

      float t = time * 0.16;
      vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3 - t)));
      vec2 r = vec2(fbm(p + 4.0 * q + vec2(1.7, 9.2)), fbm(p + 4.0 * q + vec2(8.3, 2.8)));
      float n = fbm(p + 4.8 * r + path * 0.05);

      float veins = 1.0 - smoothstep(0.055, 0.18, abs(sin((n + r.x * 0.55 + angle * 0.25) * 35.0)));
      float ridges = 1.0 - smoothstep(0.08, 0.23, abs(sin((n + q.y * 0.35 + turnWeight * 0.2) * 18.0)));
      float fine = 1.0 - smoothstep(0.012, 0.06, abs(sin((n + q.x + angle * 0.1) * 82.0)));

      vec3 col = vec3(0.005, 0.006, 0.010);
      col += vec3(0.28, 0.30, 0.32) * ridges;
      col += vec3(0.17, 0.18, 0.19) * veins;
      col += vec3(0.02, 0.03, 0.55) * fine * (0.35 + 0.65 * noise(p * 7.0 + path));
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

    write_neowall_config() {
      fps="$1"
      cfg_dir="$HOME/.config/neowall"
      mkdir -p "$cfg_dir"
      cat >"$cfg_dir/config.vibe" <<EOF
default {
  shader ${neowallShaderName}
  shader_speed ${toString (neowall.speed or 1.0)}
  shader_fps $fps
  vsync ${lib.boolToString (neowall.vsync or true)}
  show_fps ${lib.boolToString (neowall.showFps or false)}
}
EOF
    }

    start_neowall_with_fps() {
      fps="$1"
      write_neowall_config "$fps"
      start_neowall
    }

    monitor_mouse_and_manage_neowall() {
      # Requires xdotool (optional). Falls back to single start if not available.
      if command -v ${pkgs.xdotool}/bin/xdotool >/dev/null 2>&1; then
        echo "ripper-wallpaper: mouse monitor enabled (xdotool)"
        state="unknown"
        # initial start at 20 fps (quiet default)
        desired=20
        start_neowall_with_fps "$desired"
        # seed previous mouse position to avoid a large jump on first loop
        out=$(${pkgs.xdotool}/bin/xdotool getmouselocation --shell 2>/dev/null || true)
        if [ -n "$out" ]; then
          eval "$out"
          prev_x=$X
          prev_y=$Y
        else
          prev_x=0
          prev_y=0
        fi
        # parameters for scaling: max speed (pixels per sample) maps to max fps
        maxSpeed=120
        while true; do
          out=$(${pkgs.xdotool}/bin/xdotool getmouselocation --shell 2>/dev/null || true)
          if [ -z "$out" ]; then
            sleep 0.25
            continue
          fi
          eval "$out" # sets X, Y
          dx=$(( X - prev_x ))
          dy=$(( Y - prev_y ))
          # Euclidean speed (pixels per sample)
          dist=$(( dx*dx + dy*dy ))
          speed=$(awk "BEGIN{print sqrt($dist)}")
          prev_x=$X
          prev_y=$Y

          # Map speed -> ratio [0,1]
          ratio=$(awk "BEGIN{r=$speed/$maxSpeed; if(r<0) r=0; if(r>1) r=1; printf(\"%.4f\", r)}")
          # desired fps between 20 and 30
          newDesired=$(awk "BEGIN{r=$ratio; printf(\"%d\", 20 + int(r*10 + 0.5))}")

          if [ "$newDesired" -ne "$desired" ]; then
            echo "ripper-wallpaper: mouse speed=$speed ratio=$ratio switching fps to $newDesired"
            ${neowallPackage}/bin/neowall kill >/dev/null 2>&1 || true
            start_neowall_with_fps "$newDesired"
            desired=$newDesired
          fi
          sleep 0.10
        done
      else
        echo "ripper-wallpaper: xdotool not found, starting neowall once with default fps"
        start_neowall_with_fps ${toString (neowall.fps or 30)}
      fi
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
    ++ lib.optionals neowallEnable [ neowallPackage pkgs.xdotool ];

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
