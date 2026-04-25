{ config, pkgs, lib, unstable, env, nixGLCommand, ... }:

{
  imports = [
    (import ./utilities { inherit config pkgs lib unstable env nixGLCommand; })
    (import ./pentesting { inherit pkgs lib; })
  ];
}
