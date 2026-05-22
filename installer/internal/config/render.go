package config

import "fmt"

func RenderInstallConfig(cfg InstallConfig) string {
	return fmt.Sprintf(`{
  username = %q;
  homeDirectory = %q;
  hostName = %q;
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
      vsync = false;
      showFps = false;
      nice = 10;
    };
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.HostName, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}
