{ pkgs, ... }:

{
  services.picom = {
    enable = true;
    #backend = "glx";
    backend = "xrender";
    fade = true;
    fadeSteps = [ 0.03 0.03 ];

    opacityRules = [
      "95:class_g = 'kitty' && focused"
      "70:class_g = 'kitty' && !focused"
      "70:class_i = 'presel_feedback'"
    ];
  };
}
