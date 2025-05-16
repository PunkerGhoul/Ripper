{ config, pkgs, lib, nixgl, env, ... }:

{
  imports = [
    (import ./x { inherit config pkgs lib; })
    (import ./programs { inherit config pkgs nixgl env; })
    (import ./services { inherit config pkgs; })
  ];
}
