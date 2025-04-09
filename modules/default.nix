{ config, pkgs, lib, env, ... }:

{
  imports = [
    (import ./x { inherit config pkgs lib; })
    (import ./programs { inherit config pkgs env; })
    (import ./services { inherit config pkgs; })
  ];
}
