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
    defaultNeowallGlsl = builtins.readFile ./shaders/ripper.glsl;
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
        shader_fps 24
        vsync false
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

    xdotool_bin="${pkgs.xdotool}/bin/xdotool"
    focusedwindow=""
    if command -v "$xdotool_bin" >/dev/null 2>&1; then
      focusedwindow=$($xdotool_bin getactivewindow 2>/dev/null || echo "")
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
      ${pkgs.coreutils}/bin/nice -n ${toString (neowall.nice or 0)} \
        ${neowallPackage}/bin/neowall &
      pid="$!"
      ${pkgs.coreutils}/bin/sleep 0.35

      if kill -0 "$pid" 2>/dev/null; then
        echo "ripper-wallpaper: neowall is running"
      else
        if wait "$pid"; then
          echo "ripper-wallpaper: neowall started"
        fi
      fi
    }

    # start and preserve focus
    echo "ripper-wallpaper: launching neowall (preserve focus)"
    start_neowall || true

    # restore previously focused window if xdotool is available
    if command -v "$xdotool_bin" >/dev/null 2>&1 && [ -n "$focusedwindow" ]; then
      [ "$focusedwindow" != "$($xdotool_bin getactivewindow 2>/dev/null || echo "")" ] && $xdotool_bin windowfocus $focusedwindow || true
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
