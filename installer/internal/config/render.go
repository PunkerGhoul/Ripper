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
      enable = false;
      shaderName = "ripper.glsl";
      fps = 60;
      vsync = false;
      showFps = false;
      glsl = ''
        #version 100
        precision highp float;
        uniform float iTime;
        uniform vec2 iResolution;
        void main() {
          vec2 uv = gl_FragCoord.xy / iResolution.xy;
          gl_FragColor = vec4(uv, 0.5 + 0.5 * sin(iTime), 1.0);
        }
      '';
    };
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}