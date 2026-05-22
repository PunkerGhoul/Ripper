{ pkgs, ... }:

let
  # Agente de polkit personalizado para X11 usando lxqt-policykit y un cpp local mantenido en el módulo.
  lxqtPolicykitStyled = pkgs.lxqt.lxqt-policykit.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cp ${./policykitagentgui.cpp} src/policykitagentgui.cpp
      cp ${./policykitagentgui.ui} src/policykitagentgui.ui
      cp ${./policykitagent.cpp} src/policykitagent.cpp
    '';
  });
in
{
  home.packages = [ lxqtPolicykitStyled ];

  services.lxqt-policykit-agent = {
    enable = true;
    package = lxqtPolicykitStyled;
  };
}
