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
      glsl = ''precision highp float;

        void mainImage(out vec4 fragColor, in vec2 fragCoord) {
            vec2 uv = fragCoord / iResolution.xy;
            uv.x *= iResolution.x / iResolution.y;

            float waveScale = 2.4;
            vec2 wideUv = uv / waveScale;
            vec3 color = 0.5 + 0.5 * cos(iTime + wideUv.xyx + vec3(0.0, 2.0, 4.0));
            fragColor = vec4(color, 1.0);
        }
      '';
    };
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}
