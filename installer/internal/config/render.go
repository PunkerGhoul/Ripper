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
      enable = true;
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

        float proceduralTexture(vec2 p) {
            float t = iTime * 0.5;
            float waves =
                sin(p.x * 7.0 + t) +
                cos(p.y * 8.0 - t * 1.2) +
                sin((p.x + p.y) * 5.0 + t * 0.7);
            float rings = sin(length(p) * 28.0 - t * 2.0);
            return 0.5 + 0.5 * sin(waves + rings);
        }

        void main() {
            vec2 designResolution = vec2(800.0, 450.0);
            vec2 fragCoord = (gl_FragCoord.xy - 0.5 * iResolution.xy)
                / min(iResolution.x / designResolution.x, iResolution.y / designResolution.y)
                + 0.5 * designResolution;
            vec2 uv = fragCoord / designResolution;

            float aspect = designResolution.x / designResolution.y;
            vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
            float t = iTime * 0.5;

            p.x += sin(t + p.y * 10.0) * 0.08;
            p.y += cos(t + p.x * 10.0) * 0.08;

            float tex = proceduralTexture(p * 1.8);
            vec3 col = vec3(0.0, 0.0, tex);
            col = sin(col + length(col) * 30.0 + t) * 0.5 + 0.5;
            col = max((col - 0.55) * 2.0, 0.0);

            gl_FragColor = vec4(col, 1.0);
        }
      '';
    };
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}
