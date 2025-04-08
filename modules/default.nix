{ config, pkgs, lib, env, ... }:

{
  imports = [
    (import ./x { inherit config pkgs lib; })
    (import ./programs { inherit pkgs env; })
  ];
}
