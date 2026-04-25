{ pkgs, ... }:

{
  services.picom = {
    enable = true;
    #backend = "glx";
    backend = "xrender";

    extraArgs = [
      "--xrender-sync-fence false"  # Desactiva xrender-sync-fence
      "--use-damage false"  # Desactiva el uso de damage
    ];

    fade = true;
    fadeDelta = 2;
    fadeSteps = [ 0.12 0.12 ];

    settings = {
      corner-radius = 8;
      rounded-corners-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'Polybar'"
      ];
      shadow = true;
      shadow-radius = 10;
      shadow-offset-x = -4;
      shadow-offset-y = -4;
      shadow-opacity = 0.35;
      shadow-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'Polybar'"
      ];
    };

    opacityRules = [
      "95:class_g = 'kitty' && focused"
      "70:class_g = 'kitty' && !focused"
      "70:class_i = 'presel_feedback'"
    ];
  };
}
