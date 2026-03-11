{ config, pkgs, unstable, lib, env, ... }:

{
  imports = [
    (import ./x { inherit config pkgs lib; })
    (import ./programs { inherit config pkgs lib unstable env; })
    (import ./services { inherit config pkgs lib; })
  ];
}
