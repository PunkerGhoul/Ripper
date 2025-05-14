{ config, sources, pkgs, unstable, lib, env, ... }:

{
  imports = [
    (import ./x { inherit config pkgs lib; })
    (import ./programs { inherit config sources pkgs unstable env; })
    (import ./services { inherit config pkgs; })
  ];
}
