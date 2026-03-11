{ pkgs }:

pkgs.runCommandCC "polybar-reload" { } ''
  mkdir -p $out/bin
  $CC ${pkgs.replaceVars ./polybar-reload.c {
    polybarMsg = "${pkgs.polybarFull}/bin/polybar-msg";
  }} \
    -I${pkgs.xorgproto}/include \
    -I${pkgs.libX11.dev}/include \
    -I${pkgs.libXrender.dev}/include \
    -I${pkgs.libXrandr.dev}/include \
    -L${pkgs.libX11}/lib \
    -L${pkgs.libXrandr}/lib \
    -lX11 -lXrandr \
    -o $out/bin/polybar-reload
''
