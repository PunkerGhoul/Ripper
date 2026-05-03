package config

import "fmt"

func RenderInstallConfig(cfg InstallConfig) string {
	return fmt.Sprintf(`{
  username = %q;
  homeDirectory = %q;
  system = %q;
  distro = %q;
  stateVersion = %q;

  gpu = {
    wrapper = %q;
  };

  wallpaper = {
    feh = {
      enable = false;
      source = "$HOME/Pictures/Wallpapers/cyberpunk.jpg";
      mode = "center";
    };

    neowall = {
      enable = true;
      shaderName = "ripper.glsl";
      speed = 1.0;
      fps = 24;
      vsync = true;
      showFps = false;
      nice = 10;
      killBeforeStart = false;
      glsl = ''
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
    };
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}
