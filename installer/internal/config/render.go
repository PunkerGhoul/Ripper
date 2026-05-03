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
      monitorInterval = 30;
      restartDelay = 3;
      glsl = ''
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
    };
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}
