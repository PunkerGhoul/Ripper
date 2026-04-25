{ config, pkgs, unstable, lib, env, nixGLCommand, ... }:

{
  imports = [
    (import ./x { inherit config pkgs lib; })
    (import ./programs { inherit config pkgs lib unstable env nixGLCommand; })
    (import ./services { inherit config pkgs; })
  ];
}
