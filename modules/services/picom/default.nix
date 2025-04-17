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
    fadeSteps = [ 0.03 0.03 ];

    opacityRules = [
      "95:class_g = 'kitty' && focused"
      "70:class_g = 'kitty' && !focused"
      "70:class_i = 'presel_feedback'"
    ];
  };
}
